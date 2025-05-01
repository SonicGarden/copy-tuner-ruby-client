module CopyTunerClient
  # Responsible for Rails initialization
  module Rails
    # Sets up the logger, environment, name, project root, and framework name
    # for Rails applications. Must be called after framework initialization.
    def self.initialize
      CopyTunerClient.configure(false) do |config|
        config.environment_name = ::Rails.env
        config.logger           = if defined?(::Rails::Console)
          Logger.new('/dev/null')
        elsif defined?(::Rails) && ::Rails.env.development?
          Logger.new('log/copy_tuner.log')
        else
          ::Rails.logger
        end
        config.framework = "Rails: #{::Rails::VERSION::STRING}"
        config.middleware = ::Rails.configuration.middleware
        config.download_cache_dir = ::Rails.root.join('tmp', 'cache', 'copy_tuner_client')
      end
    end

    def self.controller_of_rails_engine?(controller)
      # SEE: https://github.com/rails/rails/blob/539144d2d61770dab66c8643e744441e52538e09/activesupport/lib/active_support/core_ext/module/introspection.rb#L39-L63
      engine_namespaces.include?(controller.class.module_parents[-2])
    end

    def self.engine_namespaces
      @engine_namespaces ||= ::Rails::Engine.subclasses.filter_map { _1.instance.railtie_namespace }
    end
  end
end

require 'copy_tuner_client/engine'
