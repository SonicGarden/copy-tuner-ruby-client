module CopyTunerClient
  # Starts the poller from a worker process, or register hooks for a spawner
  # process (such as in Unicorn or Passenger). Also registers hooks for exiting
  # processes and completing background jobs. Applications using the client
  # will not need to interact with this class directly.
  class ProcessGuard # rubocop:disable Metrics/ClassLength
    # Puma::Runner#start_server は worker プロセス側で呼ばれるため、そこで poller を起動する。
    # 匿名 Module だと prepend が重複するので名前付き定数にしている
    module PumaStartServerHook
      def start_server
        CopyTunerClient.poller&.start
        super
      end
    end

    # @param options [Hash]
    # @option options [Logger] :logger where errors should be logged
    def initialize(cache, poller, options)
      @cache  = cache
      @poller = poller
      @logger = options[:logger]
    end

    # Starts the poller or registers hooks
    def start
      if spawner?
        register_spawn_hooks
      else
        start_polling_locally
      end
    end

    private

    def start_polling
      @poller.start
    end

    def start_polling_locally
      register_exit_hooks
      start_polling
    end

    def spawner?
      passenger_spawner? || unicorn_spawner? || delayed_job_spawner? || good_job_spawner? || puma?
    end

    def passenger_spawner?
      defined?(PhusionPassenger) &&
        ['Passenger AppPreloader', 'ApplicationSpawner', 'rack-preloader'].any? { |name| $PROGRAM_NAME.include?(name) }
    end

    def unicorn_spawner?
      defined?(Unicorn::HttpServer) && $PROGRAM_NAME.include?('unicorn') && caller.none? { |line| line.include?('worker_loop') }
    end

    def puma?
      # $PROGRAM_NAME は `rails server` 起動では rails のパスのままで、master / single は
      # Process.setproctitle を使うため puma を含まない。Puma の有無だけで判定する。
      #
      # この判定は rails console / rake / Sidekiq など Puma をサーバとして起動していない
      # プロセスでも真になるが、それを許容している。Puma には「今 Rack サーバとして起動中か」を
      # 判定する公開 API がなく、絞り込もうとすると $0 やヒューリスティックに頼ることになり、
      # `rails server` 経由でフックが登録されないという元のバグを再発させるため。
      # 非サーバプロセスで生じるコストは puma/launcher のロード（実測 60〜70ms）と
      # prepend のみで、フック本体は start_server が呼ばれない限り発火しない。
      defined?(Puma) ? true : false
    end

    def delayed_job_spawner?
      # delayed_job は二種類の起動の仕方がある。
      # - bin/delayed_job start
      # - bin/rake jobs:work
      # 前者の呼び出しでのみジョブ処理用の子プロセスが作られるため、　poller を作るフックを仕込む必要がある。
      defined?(Delayed::Worker) && $PROGRAM_NAME.include?('delayed_job')
    end

    def good_job_spawner?
      $PROGRAM_NAME.include?('good_job') && defined?(GoodJob) && ARGV.include?('--daemonize')
    end

    def register_spawn_hooks
      if passenger_spawner?
        register_passenger_hook
      elsif unicorn_spawner?
        register_unicorn_hook
      elsif delayed_job_spawner?
        register_delayed_hook
      elsif good_job_spawner?
        register_good_job_hook
      # puma? は Puma gem がロードされていれば真になり、Web サーバ以外のプロセスでも
      # 該当してしまう。プロセスを特定できる判定を先に通し、最後の受け皿にする
      elsif puma?
        register_puma_hook
      end
    end

    def register_passenger_hook
      @logger.info('Registered Phusion Passenger fork hook')
      PhusionPassenger.on_event(:starting_worker_process) do |_forked|
        start_polling
      end
    end

    def register_unicorn_hook
      @logger.info('Registered Unicorn fork hook')
      poller = @poller
      Unicorn::HttpServer.class_eval do
        alias_method(:worker_loop_without_copy_tuner, :worker_loop)
        define_method :worker_loop do |worker|
          poller.start
          worker_loop_without_copy_tuner(worker)
        end
      end
    end

    def register_delayed_hook
      @logger.info('Registered Delayed::Job start hook')
      poller = @poller
      Delayed::Worker.class_eval do
        alias_method(:start_without_copy_tuner, :start)
        define_method :start do
          poller.start
          start_without_copy_tuner
        end
      end
    end

    def register_good_job_hook
      @logger.info('Registered good_job start hook')
      poller = @poller
      hook_module =
        Module.new do
          define_method :daemon do
            super() # NOTE: define_method 内で super を呼ぶ場合は引数を明示的に指定する必要があるので注意
            poller.start
          end
        end
      ::Process.singleton_class.prepend(hook_module)
    end

    def register_puma_hook
      # cluster モードでは master でも worker でもこのメソッドが呼ばれる。worker 側で
      # 確実に poller を動かすため、Puma::Runner#start_server にフックを仕掛ける
      if load_puma_runner
        ::Puma::Runner.prepend(PumaStartServerHook)
        @logger.info('Registered Puma fork hook')
      else
        @logger.warn('Puma fork hook was not registered')
      end

      # single モードや従来 spawner 判定が外れていた `rails server` 経由での挙動を保つため、
      # フック登録の成否に関わらず自プロセスでも poller を起動する。
      #
      # cluster の master もここを通るため、リクエストを捌かない master でも poller が 1 本立つ。
      # master と worker を区別するには $0 や Puma の内部状態を見るしかなく、そこを間違えると
      # single モードで poller が起動しなくなる。master 1 本の余分なポーリングを払う代わりに、
      # どの起動方法・モードでも必ず poller が立つことを優先している
      # （worker 側は Poller#start が pid の変化を見て張り直すため二重にはならない）。
      start_polling_locally
    end

    # Puma::Runner は lib/puma.rb の autoload に含まれず puma/launcher の require で
    # 初めて定義される。`rails server` では initializer 時点で未定義なので前倒しでロードする。
    # puma/launcher のロードは定数定義のみでスレッド生成や signal trap を伴わず、Puma で
    # 起動する場合はサーバ起動時に Puma 自身が同じ require を行うため実質的な前倒しに過ぎない
    def load_puma_runner
      return true if defined?(::Puma::Runner)

      # puma/launcher 単体の require は Puma::HAS_NATIVE_IO_WAIT 未定義で NameError になるため
      # puma を先にロードする
      require 'puma'
      require 'puma/launcher'
      defined?(::Puma::Runner) ? true : false
    rescue LoadError, NameError => e
      @logger.warn("Could not load Puma::Runner: #{e.message}")
      false
    end

    def register_exit_hooks
      at_exit do
        @cache.flush
      end
    end
  end
end
