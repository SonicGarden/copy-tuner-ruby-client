module CopyTunerClient
  class KeyAccessLog
    class NullLog
      def add(key)
      end
  
      def flush
      end
    end

    def initialize(client)
      @client = client
      @entries = {}
      @mutex = Mutex.new
    end

    def add(key_with_locale)
      return if key_with_locale.nil? || key_with_locale.empty?
      
      key = key_with_locale.split('.', 2)[1]
      return if key.nil? || key.empty?

      lock do
        @entries[key] = Time.now.to_i
      end
    end

    def flush
      to_be_uploaded = nil
      lock do
        to_be_uploaded = @entries
        @entries = {}
      end

      return if to_be_uploaded.empty?

      client.upload_key_acess_log(to_be_uploaded)
    end

    private

    attr_reader :client

    def lock(&block)
      @mutex.synchronize &block
    end
  end
end
