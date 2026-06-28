/* eslint-disable no-console */
import { CopyrayOverlay } from './copyray-overlay'
import { CopytunerBar } from './copytuner-bar'
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

const start = () => {
  const { url, data, keysSkipped } = window.CopyTuner
  const onOpen = (key: string) => window.open(`${url}/blurbs/${key}/edit`)

  const bar = document.createElement('copytuner-bar') as CopytunerBar
  document.body.append(bar)
  bar.init({ url, data, keysSkipped: Boolean(keysSkipped), onOpen })

  const overlay = document.createElement('copyray-overlay') as CopyrayOverlay
  overlay.onOpen = onOpen
  document.body.append(overlay)

  const show = () => {
    overlay.show()
    bar.show()
  }
  const hide = () => {
    overlay.hide()
    bar.hide()
  }
  const toggle = () => (overlay.isShowing ? hide() : show())

  overlay.onToggle = toggle
  window.CopyTuner.toggle = toggle

  document.addEventListener('keydown', (event) => {
    if (overlay.isShowing && ['Escape', 'Esc'].includes(event.key)) {
      hide()
      return
    }

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
