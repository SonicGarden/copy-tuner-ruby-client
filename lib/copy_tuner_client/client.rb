require 'net/http'
require 'net/https'
require 'json'
require 'copy_tuner_client/errors'

module CopyTunerClient
  # Communicates with the CopyTuner server. This class is used to actually
  # download and upload blurbs, as well as issuing deploys.
  #
  # A client is usually instantiated when {Configuration#apply} is called, and
  # the application will not need to interact with it directly.
  class Client
    # These errors will be rescued when connecting CopyTuner.
    HTTP_ERRORS = [Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
                   Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
                   Net::ProtocolError, SocketError, OpenSSL::SSL::SSLError,
                   Errno::ECONNREFUSED]

    USER_AGENT = "copy_tuner_client #{CopyTunerClient::VERSION}"

    # Usually instantiated from {Configuration#apply}. Copies options.
    # @param options [Hash]
    # @option options [String] :api_key API key of the project to connect to
    # @option options [Fixnum] :port the port to connect to
    # @option options [Boolean] :public whether to download draft or published content
    # @option options [Fixnum] :http_read_timeout how long to wait before timing out when reading data from the socket
    # @option options [Fixnum] :http_open_timeout how long to wait before timing out when opening the socket
    # @option options [Boolean] :secure whether to use SSL
    # @option options [Logger] :logger where to log transactions
    # @option options [String] :ca_file path to root certificate file for ssl verification
    def initialize(options)
      @etag = nil
      @downloaded_blurbs = {}

      [:api_key, :host, :port, :public, :http_read_timeout,
        :http_open_timeout, :secure, :logger, :ca_file, :s3_host, :download_cache_dir].each do |option|
        instance_variable_set "@#{option}", options[option]
      end

      @download_cache_dir.mkpath
      load_cachedata(last_download_path)
    end

    # Downloads all blurbs for the given api_key.
    #
    # If the +public+ option was set to +true+, this will use published blurbs.
    # Otherwise, draft content is fetched.
    #
    # The client tracks ETags between download requests, and will return
    # without yielding anything if the server returns a not modified response.
    #
    # @yield [Hash] downloaded blurbs
    # @raise [ConnectionError] if the connection fails
    def download(cache_fallback: false)
      connect(s3_host) do |http|
        request = Net::HTTP::Get.new(uri(download_resource))
        request['If-None-Match'] = @etag
        log 'Start downloading translations'
        t = Time.now
        response = http.request(request)
        t_ms = ((Time.now - t) * 1000).to_i
        downloaded = check(response)
        if downloaded
          # NOTE: Net::HTTPではgzipが透過的に扱われるため正確なファイルサイズや速度をログに出すのは難しい
          log "Downloaded translations (#{t_ms}ms)"
          @downloaded_blurbs = JSON.parse(response.body)
          @etag = response['ETag']
          last_download_path.write(JSON.pretty_generate(etag: @etag, downloaded_blurbs: @downloaded_blurbs))
        else
          log "No new translations (#{t_ms}ms)"
        end

        yield(@downloaded_blurbs) if downloaded || cache_fallback
      end
    end

    # Uploads the given hash of blurbs as draft content.
    # @param data [Hash] the blurbs to upload
    # @raise [ConnectionError] if the connection fails
    def upload(data)
      connect(host) do |http|
        response = http.post(uri('draft_blurbs'), data.to_json, 'Content-Type' => 'application/json', 'User-Agent' => USER_AGENT)
        check response
        log 'Uploaded missing translations'
      end
    end

    # Issues a deploy, marking all draft content as published for this project.
    # @raise [ConnectionError] if the connection fails
    def deploy
      connect(host) do |http|
        response = http.post(uri('deploys'), '', 'User-Agent' => USER_AGENT)
        check response
        log 'Deployed'
      end
    end

    private

    attr_reader :host, :port, :api_key, :http_read_timeout,
      :http_open_timeout, :secure, :logger, :ca_file, :s3_host

    def public?
      @public
    end

    def uri(resource)
      "/api/v2/projects/#{api_key}/#{resource}"
    end

    def download_resource
      if public?
        'published_blurbs.json'
      else
        'draft_blurbs.json'
      end
    end

    def last_download_path
      @download_cache_dir.join("last-download-#{download_resource}")
    end

    def load_cachedata(pathname)
      return unless pathname.exist?

      cache = JSON.parse(pathname.read.to_s).transform_keys(&:to_sym)
      @etag = cache[:etag]
      @downloaded_blurbs = cache[:downloaded_blurbs]
      log "Loaded cache data from #{pathname}"
    rescue JSON::JSONError, Errno::ENOENT, Errno::ENOTDIR
      nil
    end

    def connect(host)
      http = Net::HTTP.new(host, port)
      http.open_timeout = http_open_timeout
      http.read_timeout = http_read_timeout
      http.use_ssl = secure
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.ca_file = ca_file

      begin
        yield http
      rescue *HTTP_ERRORS => exception
        raise ConnectionError, "#{exception.class.name}: #{exception.message}"
      end
    end

    def check(response)
      case response
      when Net::HTTPNotFound
        raise InvalidApiKey, "Invalid API key: #{api_key}"
      when Net::HTTPNotModified
        false
      when Net::HTTPSuccess
        true
      else
        raise ConnectionError, "#{response.code}: #{response.body}"
      end
    end

    def log(message)
      logger.info message
    end
  end
end
