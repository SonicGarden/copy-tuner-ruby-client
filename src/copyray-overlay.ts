import { OVERLAY_STYLES } from './styles'
import { demoteFromTopLayer, hideFromTopLayer, promoteToTopLayer, showOnTopLayer, topLayerHost } from './top-layer'
import { computeBoundingBox } from './util'

type OpenCallback = (key: string) => void

type Blurb = {
  keys: string[]
  element: Element
}

const findBlurbs = (): Blurb[] =>
  Array.from(document.querySelectorAll('[data-copyray-key]')).map((element) => ({
    // 1 要素に複数キーがカンマ区切りで入りうる（同一テキストノードに複数訳文が連結された場合）
    keys: (element.getAttribute('data-copyray-key') ?? '').split(',').filter(Boolean),
    element,
  }))

// オーバーレイ背景・翻訳要素のハイライト枠（specimen）・トグルボタンをまとめて Shadow DOM 内に描画する。
export class CopyrayOverlay extends HTMLElement {
  #onOpen: OpenCallback = () => {}
  #onToggle: () => void = () => {}
  #backdrop: HTMLDivElement
  #specimens: HTMLDivElement
  #toggleButton: HTMLAnchorElement

  constructor() {
    super()
    const shadow = this.attachShadow({ mode: 'open' })

    const style = document.createElement('style')
    style.textContent = OVERLAY_STYLES
    shadow.append(style)

    this.#backdrop = document.createElement('div')
    this.#backdrop.classList.add('backdrop')
    this.#backdrop.addEventListener('click', () => this.hide())

    // specimen をページ座標基準で absolute 配置するコンテナ
    this.#specimens = document.createElement('div')
    this.#specimens.classList.add('specimens')

    this.#toggleButton = document.createElement('a')
    this.#toggleButton.classList.add('toggle-button')
    this.#toggleButton.textContent = 'Open CopyTuner'
    // 旧実装ではトグルボタンが overlay と bar の両方を表示していた。show() ではなく onToggle 経由で表示する。
    this.#toggleButton.addEventListener('click', () => this.#onToggle())

    shadow.append(this.#backdrop, this.#specimens, this.#toggleButton)

    // 初期は非表示。トグルボタンは常時表示のため :host([hidden]) は使わず、backdrop だけ隠す
    // （hide() は属性変更・DOM 移動を伴い constructor 内では呼べない）。
    this.#backdrop.hidden = true
  }

  set onOpen(callback: OpenCallback) {
    this.#onOpen = callback
  }

  set onToggle(callback: () => void) {
    this.#onToggle = callback
  }

  get isShowing(): boolean {
    return !this.#backdrop.hidden
  }

  show() {
    this.reset()

    promoteToTopLayer(this)
    topLayerHost().append(this)
    showOnTopLayer(this)
    this.#syncScrollOffset()
    window.addEventListener('scroll', this.#syncScrollOffset)

    this.#backdrop.hidden = false

    for (const { element, keys } of findBlurbs()) {
      const box = this.makeBox(element, keys)
      if (box) {
        this.#specimens.append(box)
      }
    }
  }

  hide() {
    this.reset()
    this.#backdrop.hidden = true

    window.removeEventListener('scroll', this.#syncScrollOffset)
    hideFromTopLayer(this)
    demoteFromTopLayer(this)
    // dialog内に退避したままだとdialogのDOM削除に巻き込まれるため、bodyへ戻す
    document.body.append(this)
  }

  reset() {
    this.#specimens.replaceChildren()
  }

  // transform でずらすと fixed 配置の specimen の基準が変わるため、top/left でスクロール量を打ち消す。
  // hasAttribute を先に見るのは、非対応ブラウザでは :popover-open が不明なセレクタで matches が例外を投げるため。
  #syncScrollOffset = () => {
    const isOnTopLayer = this.hasAttribute('popover') && this.matches(':popover-open')
    this.#specimens.style.top = isOnTopLayer ? `${-window.scrollY}px` : ''
    this.#specimens.style.left = isOnTopLayer ? `${-window.scrollX}px` : ''
  }

  private makeBox(element: Element, keys: string[]): HTMLDivElement | null {
    const bounds = computeBoundingBox(element)
    if (bounds === null) return null

    const box = document.createElement('div')
    box.classList.add('specimen')
    box.style.left = `${bounds.left}px`
    box.style.top = `${bounds.top}px`
    box.style.width = `${bounds.width}px`
    box.style.height = `${bounds.height}px`

    const { position, top, left } = getComputedStyle(element)
    if (position === 'fixed') {
      box.style.position = 'fixed'
      box.style.top = top
      box.style.left = left
    }

    // box 全体のクリックは先頭キーを開く（広いクリック領域を維持）。複数キー時は各ラベルから個別に開ける
    box.addEventListener('click', () => this.#onOpen(keys[0]))

    for (const key of keys) {
      box.append(this.makeLabel(key))
    }
    return box
  }

  private makeLabel(key: string): HTMLDivElement {
    const label = document.createElement('div')
    label.classList.add('specimen-handle')
    label.textContent = key
    // ラベルのクリックはそのキーを開く。box への伝播を止めて先頭キーとの二重発火を防ぐ
    label.addEventListener('click', (event) => {
      event.stopPropagation()
      this.#onOpen(key)
    })
    return label
  }
}
