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
    # フックは CopyTunerClient.configuration&.poller を見るので、実際の設定に載せる
    CopyTunerClient.configuration.poller = poller
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

  describe 'poller を取得できないとき' do
    it 'configuration が nil でも fork を壊さない' do
      # Process._fork への prepend は外せないので、ここで例外を漏らすとアプリの
      # すべての fork が失敗する
      CopyTunerClient.configuration = nil

      expect { Process.waitpid(fork { exit!(0) }) }.not_to raise_error
    end

    it 'ログ出力自体が失敗しても fork は成立する' do
      allow(poller).to receive(:stop).and_return(true)
      allow(poller).to receive(:start).and_raise(ThreadError, 'cannot create thread')
      allow(CopyTunerClient.configuration.logger).to receive(:error).and_raise('logger is broken')

      expect { Process.waitpid(fork { exit!(0) }) }.not_to raise_error
    end

    it 'fork 後の poller 起動に失敗しても fork 自体は成立する' do
      allow(poller).to receive(:stop).and_return(true)
      allow(poller).to receive(:start).and_raise(ThreadError, 'cannot create thread')

      expect { Process.waitpid(fork { exit!(0) }) }.not_to raise_error
    end
  end

  describe '実際に fork したとき' do
    it 'fork 前に poller が例外で死んでいても親子とも張り直す' do
      # rails server の cluster では ForkHook が唯一の再開経路なので、ここで張り直さないと
      # 親子とも poller を失う
      fail_once = true
      allow(cache).to receive(:sync).and_wrap_original do |original, *args|
        if fail_once
          fail_once = false
          raise 'boom'
        end
        original.call(*args)
      end

      poller.start
      sleep(polling_delay * 0.4) # スレッドが例外で終わる

      reader, writer = IO.pipe
      pid =
        fork do
          reader.close
          client['child.key'] = 'value'
          sleep(polling_delay * 3)
          writer.write(cache['child.key'].to_s)
          writer.close
          exit!(0)
        end

      writer.close
      child_result = reader.read
      Process.waitpid(pid)

      client['parent.key'] = 'value'
      sleep(polling_delay * 3)

      expect(child_result).to eq('value')
      expect(cache['parent.key']).to eq('value')
    end

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
