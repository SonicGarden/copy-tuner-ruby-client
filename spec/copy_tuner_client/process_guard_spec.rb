require 'spec_helper'

describe CopyTunerClient::ProcessGuard do
  include DefinesConstants

  let!(:original_process_name) { $PROGRAM_NAME }
  let(:cache) { instance_double(CopyTunerClient::Cache, flush: nil) }
  let(:poller) { instance_double(CopyTunerClient::Poller, start: nil) }

  after do
    $0 = original_process_name
  end

  def build_process_guard(options = {})
    preserve_exit_hook = options.delete(:preserve_exit_hook)
    options[:logger] ||= FakeLogger.new
    options[:cache]  ||= cache
    process_guard = CopyTunerClient::ProcessGuard.new(options[:cache], poller, options)
    allow(process_guard).to receive(:register_exit_hooks) unless preserve_exit_hook
    process_guard
  end

  it 'worker プロセスから poller を起動する' do
    process_guard = build_process_guard
    process_guard.start

    expect(poller).to have_received(:start)
  end

  it 'passenger のマスタープロセスから passenger フックを登録する' do
    logger = FakeLogger.new
    passenger = define_constant('PhusionPassenger', FakePassenger.new)
    passenger.become_master

    process_guard = build_process_guard(logger:)
    process_guard.start

    expect(poller).not_to have_received(:start)
    expect(logger).to have_entry(:info, 'Registered Phusion Passenger fork hook')
  end

  it 'passenger の worker から poller を起動する' do
    logger = FakeLogger.new
    passenger = define_constant('PhusionPassenger', FakePassenger.new)
    passenger.become_master
    process_guard = build_process_guard(logger:)

    process_guard.start
    passenger.spawn

    expect(poller).to have_received(:start)
  end

  it 'unicorn のマスタープロセスから unicorn フックを登録する' do
    logger = FakeLogger.new
    define_constant('Unicorn', Module.new)
    http_server = Class.new(FakeUnicornServer)
    unicorn = define_constant('Unicorn::HttpServer', http_server).new
    unicorn.become_master

    process_guard = build_process_guard(logger:)
    process_guard.start

    expect(poller).not_to have_received(:start)
    expect(logger).to have_entry(:info, 'Registered Unicorn fork hook')
  end

  it 'unicorn の worker から poller を起動する' do
    logger = FakeLogger.new
    define_constant('Unicorn', Module.new)
    http_server = Class.new(FakeUnicornServer)
    unicorn = define_constant('Unicorn::HttpServer', http_server).new
    unicorn.become_master
    process_guard = build_process_guard(logger:)

    process_guard.start
    unicorn.spawn

    expect(poller).to have_received(:start)
  end

  it 'Puma が読み込まれていても delayed_job のプロセスでは delayed_job フックを登録する' do
    define_constant('Puma', Module.new)
    define_constant('Delayed', Module.new)
    define_constant('Delayed::Worker', Class.new(FakeDelayedWorker))
    $0 = 'delayed_job'
    logger = FakeLogger.new

    build_process_guard(logger:).start

    expect(logger).to have_entry(:info, 'Registered Delayed::Job start hook')
  end

  describe 'Puma' do
    # PumaStartServerHook はインスタンスを捕捉できないため CopyTunerClient.poller を参照する
    before do
      allow(CopyTunerClient).to receive(:poller).and_return(poller)
    end

    def define_puma_runner
      define_constant('Puma', Module.new)
      define_constant('Puma::Runner', Class.new(FakePumaRunner))
    end

    context 'Puma::Runner が既に定義されているとき' do
      it 'start_server で poller が起動するフックを仕掛ける' do
        runner_class = define_puma_runner
        process_guard = build_process_guard
        process_guard.start

        runner_class.new.start_server

        # master プロセス側の start と start_server 側の start で 2 回
        expect(poller).to have_received(:start).twice
      end

      it 'master プロセスでも poller を起動する' do
        define_puma_runner
        process_guard = build_process_guard
        process_guard.start

        expect(poller).to have_received(:start)
      end

      it 'フックを登録したことをログに残す' do
        define_puma_runner
        logger = FakeLogger.new
        build_process_guard(logger:).start

        expect(logger).to have_entry(:info, 'Registered Puma fork hook')
      end

      it '二度 start してもフックは重複せず start_server 1 回で poller の起動も 1 回' do
        runner_class = define_puma_runner
        build_process_guard.start
        build_process_guard.start
        runner = runner_class.new

        # master プロセス側の start を数に含めないよう、ここで記録をリセットする
        RSpec::Mocks.space.proxy_for(poller).reset
        allow(poller).to receive(:start)

        runner.start_server

        expect(poller).to have_received(:start).once
      end
    end

    context 'Puma::Runner が未定義のとき' do
      it 'require して定義されたクラスにフックを仕掛ける' do
        define_constant('Puma', Module.new)
        runner_class = Class.new(FakePumaRunner)
        process_guard = build_process_guard

        allow(process_guard).to receive(:require) do |name|
          define_constant('Puma::Runner', runner_class) if name == 'puma/launcher'
          true
        end

        process_guard.start

        expect(process_guard).to have_received(:require).with('puma')
        expect(process_guard).to have_received(:require).with('puma/launcher')

        runner_class.new.start_server

        expect(poller).to have_received(:start).twice
      end
    end

    context 'require に失敗したとき' do
      it '例外を投げずに poller を起動し警告を残す' do
        define_constant('Puma', Module.new)
        logger = FakeLogger.new
        process_guard = build_process_guard(logger:)
        allow(process_guard).to receive(:require).and_raise(LoadError, 'cannot load such file -- puma')

        expect { process_guard.start }.not_to raise_error

        expect(poller).to have_received(:start)
        expect(logger).to have_entry(:warn, 'Could not load Puma::Runner')
      end

      it 'NameError でも例外を投げない' do
        define_constant('Puma', Module.new)
        process_guard = build_process_guard
        allow(process_guard).to receive(:require).and_raise(NameError, 'uninitialized constant Puma::HAS_NATIVE_IO_WAIT')

        expect { process_guard.start }.not_to raise_error

        expect(poller).to have_received(:start)
      end
    end
  end

  it 'プロセス終了時に flush する' do
    cache = WritingCache.new
    FileUtils.rm_f(File.join(PROJECT_ROOT, 'tmp', 'written_cache'))
    fork do
      process_guard = build_process_guard(cache:, preserve_exit_hook: true)
      process_guard.start
      exit
    end
    Process.wait

    expect(cache).to be_written
  end
end
