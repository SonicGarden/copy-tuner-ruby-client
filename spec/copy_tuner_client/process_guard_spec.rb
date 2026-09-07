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

  it 'fork の前後で poller を張り直すフックを登録する' do
    allow(CopyTunerClient::ForkHook).to receive(:install)

    build_process_guard.start

    expect(CopyTunerClient::ForkHook).to have_received(:install)
  end

  it 'starts polling from a worker process' do
    process_guard = build_process_guard
    process_guard.start

    expect(poller).to have_received(:start)
  end

  it 'registers passenger hooks from the passenger master' do
    logger = FakeLogger.new
    passenger = define_constant('PhusionPassenger', FakePassenger.new)
    passenger.become_master

    process_guard = build_process_guard(logger:)
    process_guard.start

    expect(poller).not_to have_received(:start)
    expect(logger).to have_entry(:info, 'Registered Phusion Passenger fork hook')
  end

  it 'starts polling from a passenger worker' do
    logger = FakeLogger.new
    passenger = define_constant('PhusionPassenger', FakePassenger.new)
    passenger.become_master
    process_guard = build_process_guard(logger:)

    process_guard.start
    passenger.spawn

    expect(poller).to have_received(:start)
  end

  it 'registers unicorn hooks from the unicorn master' do
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

  it 'starts polling from a unicorn worker' do
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

  it 'flushes when the process terminates' do
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
