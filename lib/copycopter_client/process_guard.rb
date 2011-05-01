module CopycopterClient
  # Starts the sync from a worker process, or register hooks for a spawner
  # process (such as in Unicorn or Passenger). Also registers hooks for exiting
  # processes and completing background jobs. Applications using the client
  # will not need to interact with this class directly.
  class ProcessGuard
    # @param options [Hash]
    # @option options [Logger] :logger where errors should be logged
    def initialize(sync, options)
      @sync   = sync
      @logger = options[:logger]
    end

    # Starts the sync or registers hooks
    def start
      if spawner?
        register_spawn_hooks
      else
        register_exit_hooks
        register_job_hooks
        start_sync
      end
    end

    private

    def start_sync
      @sync.start
    end

    def spawner?
      passenger_spawner? || unicorn_spawner?
    end

    def passenger_spawner?
      $0.include?("ApplicationSpawner")
    end

    def unicorn_spawner?
      $0.include?("unicorn") && !caller.any? { |line| line.include?("worker_loop") }
    end

    def register_spawn_hooks
      if defined?(PhusionPassenger)
        register_passenger_hook
      elsif defined?(Unicorn::HttpServer)
        register_unicorn_hook
      end
    end

    def register_passenger_hook
      @logger.info("Registered Phusion Passenger fork hook")
      PhusionPassenger.on_event(:starting_worker_process) do |forked|
        start_sync
      end
    end

    def register_unicorn_hook
      @logger.info("Registered Unicorn fork hook")
      sync = @sync
      Unicorn::HttpServer.class_eval do
        alias_method :worker_loop_without_copycopter, :worker_loop
        define_method :worker_loop do |worker|
          sync.start
          worker_loop_without_copycopter(worker)
        end
      end
    end

    def register_exit_hooks
      at_exit do
        @sync.flush
      end
    end

    def register_job_hooks
      if defined?(Resque)
        @logger.info("Registered Resque after_perform hook")
        sync = @sync
        Resque::Job.class_eval do
          alias_method :perform_without_copycopter, :perform
          define_method :perform do
            job_was_performed = perform_without_copycopter
            sync.flush
            job_was_performed
          end
        end
      end
    end
  end
end
