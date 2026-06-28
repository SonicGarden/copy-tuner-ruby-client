import { BAR_STYLES } from './styles'
import { debounce } from './util'

type OpenCallback = (key: string) => void

type InitOptions = {
  url: string
  data: Record<string, string>
  keysSkipped: boolean
  onOpen: OpenCallback
}

// 画面下部のツールバー。CopyTuner / Sync ボタン、ページ内翻訳の検索・ログメニューを Shadow DOM 内に描画する。
export class CopytunerBar extends HTMLElement {
  #onOpen: OpenCallback = () => {}
  #searchBox!: HTMLInputElement
  #logMenu!: HTMLDivElement

  constructor() {
    super()
    this.attachShadow({ mode: 'open' })
  }

  // custom element の constructor 内では属性・プロパティを変更できない（createElement が弾く）ため、
  // hidden の初期化は DOM 挿入後に呼ばれる connectedCallback で行う。
  connectedCallback() {
    this.hidden = true
  }

  // url/data/keysSkipped/onOpen はオブジェクトや関数を含むため属性ではなくメソッドで受け渡す。
  init({ url, data, keysSkipped, onOpen }: InitOptions) {
    this.#onOpen = onOpen
    const shadow = this.shadowRoot as ShadowRoot

    const style = document.createElement('style')
    style.textContent = BAR_STYLES
    shadow.append(style)

    // 元々 Rails から出力されていたマークアップに合わせたボタン群。
    // url は設定値だが innerHTML に直接埋めず setAttribute で渡す（XSS 面で安全側に倒す）。
    const copyTunerButton = this.makeButton('CopyTuner', url, '_blank')
    const syncButton = this.makeButton('Sync', '/copytuner', '_blank')
    const openLogButton = this.makeButton('Translations in this page', 'javascript:void(0)')

    this.#searchBox = document.createElement('input')
    this.#searchBox.type = 'text'
    this.#searchBox.classList.add('search')
    this.#searchBox.placeholder = 'search'

    shadow.append(copyTunerButton, syncButton, openLogButton, this.#searchBox)

    this.#logMenu = this.makeLogMenu(data)
    shadow.append(this.#logMenu)

    // 巨大DOM/Nokogiri例外でキー付与がスキップされた場合は、オーバーレイが使えないので
    // ツールバー（Translations in this page）から編集する旨を案内する。
    if (keysSkipped) {
      this.appendSkippedNotice()
    }

    openLogButton.addEventListener('click', (event) => {
      event.preventDefault()
      this.toggleLogMenu()
    })
    this.#searchBox.addEventListener('input', debounce(this.onSearch.bind(this), 250))
  }

  show() {
    this.hidden = false
    this.#searchBox.focus()
  }

  hide() {
    this.hidden = true
  }

  private makeButton(label: string, href: string, target?: string): HTMLAnchorElement {
    const button = document.createElement('a')
    button.classList.add('button')
    button.textContent = label
    button.href = href
    if (target) {
      button.target = target
    }
    return button
  }

  private appendSkippedNotice() {
    const notice = document.createElement('span')
    notice.classList.add('notice')
    notice.textContent = '⚠ This page is too large for the overlay. Use "Translations in this page" to edit.'
    ;(this.shadowRoot as ShadowRoot).append(notice)
  }

  private showLogMenu() {
    this.#logMenu.hidden = false
  }

  private toggleLogMenu() {
    this.#logMenu.hidden = !this.#logMenu.hidden
  }

  private makeLogMenu(data: Record<string, string>): HTMLDivElement {
    const div = document.createElement('div')
    div.classList.add('log-menu')
    div.hidden = true

    const table = document.createElement('table')
    const tbody = document.createElement('tbody')

    for (const key of Object.keys(data).sort()) {
      const value = data[key]
      if (value === '') {
        continue
      }

      const td1 = document.createElement('td')
      td1.textContent = key
      const td2 = document.createElement('td')
      td2.textContent = value
      const tr = document.createElement('tr')
      tr.dataset.key = key

      tr.addEventListener('click', ({ currentTarget }) => {
        const row = currentTarget as HTMLTableRowElement
        if (row.dataset.key) {
          this.#onOpen(row.dataset.key)
        }
      })

      tr.append(td1, td2)
      tbody.append(tr)
    }

    table.append(tbody)
    div.append(table)

    return div
  }

  private onSearch() {
    // debounce 経由で遅延実行されると Event.target は null 化されるため、検索ボックスを直接参照する
    const keyword = this.#searchBox.value.trim()
    this.showLogMenu()

    const rows = [...this.#logMenu.querySelectorAll('tr')]
    for (const row of rows) {
      const isShow =
        keyword === '' || [...row.querySelectorAll('td')].some((td) => (td.textContent ?? '').includes(keyword))
      row.hidden = !isShow
    }
  }
}
