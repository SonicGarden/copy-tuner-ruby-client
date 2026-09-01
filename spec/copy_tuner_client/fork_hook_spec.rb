require 'spec_helper'

describe CopyTunerClient::ForkHook do
  let(:client) { FakeClient.new }
  let(:cache) { CopyTunerClient::Cache.new(client, logger: FakeLogger.new) }
  let(:poller) do
    config = CopyTunerClient::Configuration.new.to_hash
    CopyTunerClient::Poller.new(cache, config.update(logger: FakeLogger.new, polling_delay:))
  end

  def polling_delay
    0.5
  end

  before do
    described_class.install
    allow(CopyTunerClient).to receive(:poller).and_return(poller)
  end

  after do
    poller.stop
  end

  describe '停止と再開の順序' do
    # 実際に fork してしまうと「fork の瞬間にスレッドが止まっているか」を観測できないため、
    # _fork の代わりに記録だけするオブジェクトに prepend して順序を見る
    def build_forkable(events, &fork_body)
      forkable = Object.new
      forkable.define_singleton_method(:_fork) do
        events << :fork
        fork_body ? fork_body.call : 0
      end
      forkable.singleton_class.prepend(described_class)
      forkable
    end

    def stub_poller(events, stopped:)
      allow(poller).to receive(:stop) do
        events << :stop
        stopped
      end
      allow(poller).to receive(:start) { events << :start }
    end

    it 'fork の前に poller を停止し、fork の後に再開する' do
      events = []
      stub_poller(events, stopped: true)

      build_forkable(events)._fork

      expect(events).to eq(%i[stop fork start])
    end

    it 'fork 前に poller が動いていなければ再開しない' do
      events = []
      stub_poller(events, stopped: false)

      build_forkable(events)._fork

      expect(events).to eq(%i[stop fork])
    end

    it 'fork が失敗しても poller を再開する' do
      events = []
      stub_poller(events, stopped: true)

      forkable = build_forkable(events) { raise Errno::EAGAIN }

      expect { forkable._fork }.to raise_error(Errno::EAGAIN)
      expect(events).to eq(%i[stop fork start])
    end
  end

  describe '実際に fork したとき' do
    it '子プロセスでも poller がポーリングを続ける' do
      poller.start
      reader, writer = IO.pipe

      pid =
        fork do
          reader.close
          client['test.key'] = 'value'
          sleep(polling_delay * 3)
          writer.write(cache['test.key'].to_s)
          writer.close
          exit!(0)
        end

      writer.close
      result = reader.read
      Process.waitpid(pid)

      expect(result).to eq('value')
    end

    it '親プロセスでも poller がポーリングを続ける' do
      poller.start
      sleep(polling_delay * 0.2)

      Process.waitpid(fork { exit!(0) })

      client['test.key'] = 'value'
      sleep(polling_delay * 3)

      expect(cache['test.key']).to eq('value')
    end
  end
end
