require 'net/http'

# Starts a Rails application server in a fork and waits for it to be responsive
class RailsServer
  HOST = 'localhost'.freeze

  class << self
    attr_accessor :instance
  end

  def self.start(port = nil, debug = nil)
    self.instance = new(port, debug)
    self.instance.start
    self.instance
  end

  def self.stop
    self.instance.stop if instance
    self.instance = nil
  end

  def self.get(path)
    self.instance.get(path)
  end

  def self.post(path, data)
    self.instance.post(path, data)
  end

  def self.run(port, silent)
    if silent
      require 'stringio'
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    require './config/environment'
    require 'thin'

    if Rails::VERSION::MAJOR == 3 or Rails::VERSION::MAJOR == 4
      rails = Rails.application
    else
      rails = ActionController::Dispatcher.new
    end
    app = Identify.new(rails)

    Thin::Logging.silent = silent
    Rack::Handler::Thin.run(app, :Port => port, :AccessLog => [])
  end

  def self.app_host
    self.instance.app_host
  end

  def initialize(port, debug)
    @port = (port || 3001).to_i
    @debug = debug
  end

  def start
    @pid = fork do
      command = "ruby -r#{__FILE__} -e 'RailsServer.run(#{@port}, #{(!@debug).inspect})'"
      puts command if @debug
      exec(command)
    end
    wait_until_responsive
  end

  def stop
    if @pid
      Process.kill('INT', @pid)

      begin
        Timeout.timeout(20) do
          Process.wait
        end
      rescue Timeout::Error
        Process.kill(9, @pid)
        Process.wait(@pid)
      end
      @pid = nil
    end
  end

  def get(path)
    puts "GET #{path}" if @debug
    Net::HTTP.start(HOST, @port) { |http| http.get(path) }
  end

  def post(path, data)
    puts "POST #{path}\n#{data}" if @debug
    Net::HTTP.start(HOST, @port) { |http| http.post(path, data) }
  end

  def wait_until_responsive
    20.times do
      if responsive?
        return true
      else
        sleep(0.5)
      end
    end
    raise "Couldn't connect to Rails application server at #{HOST}:#{@port}"
  end

  def responsive?
    response = Net::HTTP.start(HOST, @port) { |http| http.get('/__identify__') }
    response.is_a?(Net::HTTPSuccess)
  rescue Errno::ECONNREFUSED, Errno::EBADF
    return false
  end

  def app_host
    "http://#{HOST}:#{@port}"
  end

  # From Capybara::Server

  class Identify
    def initialize(app)
      @app = app
    end

    def call(env)
      if env["PATH_INFO"] == "/__identify__"
        [200, {}, 'OK']
      else
        @app.call(env)
      end
    end
  end
end
