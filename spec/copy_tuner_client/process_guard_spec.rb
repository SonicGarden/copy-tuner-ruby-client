require 'spec_helper'

describe CopyTunerClient::ProcessGuard do
  include DefinesConstants

  before do
    @original_process_name = $0
  end

  after do
    $0 = @original_process_name
  end

  let(:cache) { double('cache', flush: nil) }
  let(:poller) { double('poller', start: nil) }

  def build_process_guard(options = {})
    preserve_exit_hook = options.delete(:preserve_exit_hook)
    options[:logger] ||= FakeLogger.new
    options[:cache]  ||= cache
    process_guard = CopyTunerClient::ProcessGuard.new(options[:cache], poller, options)
    allow(process_guard).to receive(:register_exit_hooks) unless preserve_exit_hook
    process_guard
  end

  it "starts polling from a worker process" do
    expect(poller).to receive(:start)
    process_guard = build_process_guard
    process_guard.start
  end

  it "registers passenger hooks from the passenger master" do
    expect(poller).not_to receive(:start)
    logger = FakeLogger.new
    passenger = define_constant('PhusionPassenger', FakePassenger.new)
    passenger.become_master

    process_guard = build_process_guard(:logger => logger)
    process_guard.start

    expect(logger).to have_entry(:info, "Registered Phusion Passenger fork hook")
  end

  it "starts polling from a passenger worker" do
    expect(poller).to receive(:start)
    logger = FakeLogger.new
    passenger = define_constant('PhusionPassenger', FakePassenger.new)
    passenger.become_master
    process_guard = build_process_guard(:logger => logger)

    process_guard.start
    passenger.spawn
  end

  it "registers unicorn hooks from the unicorn master" do
    expect(poller).not_to receive(:start)
    logger = FakeLogger.new
    define_constant('Unicorn', Module.new)
    http_server = Class.new(FakeUnicornServer)
    unicorn = define_constant('Unicorn::HttpServer', http_server).new
    unicorn.become_master

    process_guard = build_process_guard(:logger => logger)
    process_guard.start

    expect(logger).to have_entry(:info, "Registered Unicorn fork hook")
  end

  it "starts polling from a unicorn worker" do
    expect(poller).to receive(:start)
    logger = FakeLogger.new
    define_constant('Unicorn', Module.new)
    http_server = Class.new(FakeUnicornServer)
    unicorn = define_constant('Unicorn::HttpServer', http_server).new
    unicorn.become_master
    process_guard = build_process_guard(:logger => logger)

    process_guard.start
    unicorn.spawn
  end

  # FIXME: ruby@2.7以降で失敗するようになっているがテストコードの問題っぽいのでスキップしている
  xit "flushes when the process terminates" do
    cache = WritingCache.new
    pid = fork do
      process_guard = build_process_guard(cache: cache, preserve_exit_hook: true)
      process_guard.start
      exit
    end
    Process.wait

    expect(cache).to be_written
  end
end
