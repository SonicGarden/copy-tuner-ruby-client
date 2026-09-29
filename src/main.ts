/* eslint-disable no-console */
import { CopyrayOverlay } from './copyray-overlay'
import { CopytunerBar } from './copytuner-bar'
import { CopytunerRoot } from './copytuner-root'
import { isMac } from './util'

declare global {
  interface Window {
    CopyTuner: {
      url: string
      toggle?: () => void
      data: Record<string, string>
      // 巨大DOM/Nokogiri例外で data-copyray-key 付与をスキップしたか。
      // true のときオーバーレイは使えないのでツールバーから編集する旨を案内する。
      keysSkipped?: boolean
    }
  }
}

customElements.define('copytuner-bar', CopytunerBar)
customElements.define('copyray-overlay', CopyrayOverlay)
customElements.define('copytuner-root', CopytunerRoot)

const start = () => {
  const { url, data, keysSkipped } = window.CopyTuner
  const onOpen = (key: string) => window.open(`${url}/blurbs/${key}/edit`)

  const root = document.createElement('copytuner-root') as CopytunerRoot
  document.body.append(root)

  const bar = document.createElement('copytuner-bar') as CopytunerBar
  const overlay = document.createElement('copyray-overlay') as CopyrayOverlay
  overlay.onOpen = onOpen
  root.dialog.append(overlay, bar)
  bar.init({ url, data, keysSkipped: Boolean(keysSkipped), onOpen })

  const show = () => {
    // display: none のままでは searchBox にフォーカスが当たらないので dialog を先に開く
    root.dialog.showModal()
    overlay.show()
    bar.show()
  }
  const hide = () => {
    root.dialog.close()
    // close イベントを待たず同期で後始末する。イベントは queued task 発火で、
    // 自動テスト環境など発火が遅れる/落ちる状況があるため、ここを唯一の頼りにしない
    overlay.hide()
  }
  const toggle = () => (root.dialog.open ? hide() : show())

  root.onToggle = toggle
  overlay.onClose = hide
  window.CopyTuner.toggle = toggle

  // Escape のようにこちらの hide() を経由しない閉じ方の受け皿。overlay.hide() は冪等なので二重でも問題ない
  root.dialog.addEventListener('close', () => {
    // 閉じた直後に開き直された場合、遅れて届いたこのイベントで後始末してはいけない
    if (root.dialog.open) return
    overlay.hide()
  })

  document.addEventListener('keydown', (event) => {
    if (((isMac && event.metaKey) || (!isMac && event.ctrlKey)) && event.shiftKey && event.key.toLowerCase() === 'k') {
      toggle()
    }
  })

  if (console) {
    console.log(`Ready to Copyray. Press ${isMac ? 'cmd+shift+k' : 'ctrl+shift+k'} to scan your UI.`)
  }
}

if (document.readyState === 'complete' || document.readyState !== 'loading') {
  start()
} else {
  document.addEventListener('DOMContentLoaded', () => start())
}
