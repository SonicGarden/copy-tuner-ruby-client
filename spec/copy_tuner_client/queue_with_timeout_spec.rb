require 'spec_helper'
require 'timeout'

describe CopyTunerClient::QueueWithTimeout do
  subject(:queue) { described_class.new }

  describe '#pop_with_timeout' do
    it 'キューに要素があれば取り出す' do
      queue << :sync

      expect(queue.pop_with_timeout(0)).to eq(:sync)
    end

    it '要素が無いままタイムアウトしたら ThreadError を投げる' do
      expect { queue.pop_with_timeout(0.1) }.to raise_error(ThreadError)
    end

    it 'ウォールクロックが巻き戻ってもタイムアウトが伸びない' do
      # 待っている最中に NTP の step 補正や手動の時刻変更で時計が後ろへ飛ぶ状況を模す。
      # 経過時間をウォールクロックで測っていると、飛んだ幅がそのまま待ち時間に乗る
      base = Time.now
      allow(Time).to receive(:now).and_return(base, base - 3600)

      expect { Timeout.timeout(2) { queue.pop_with_timeout(0.1) } }.to raise_error(ThreadError)
    end
  end
end
