import { OVERLAY_STYLES } from './styles'
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

    // 暗転背景。クリックで閉じる。
    this.#backdrop = document.createElement('div')
    this.#backdrop.classList.add('backdrop')
    this.#backdrop.addEventListener('click', () => this.hide())

    // specimen をページ座標基準で absolute 配置するコンテナ
    this.#specimens = document.createElement('div')
    this.#specimens.classList.add('specimens')

    // 常時表示のトグルボタン（画面左下固定）
    this.#toggleButton = document.createElement('a')
    this.#toggleButton.classList.add('toggle-button')
    this.#toggleButton.textContent = 'Open CopyTuner'
    // 旧実装ではトグルボタンが overlay と bar の両方を表示していた。show() ではなく onToggle 経由で表示する。
    this.#toggleButton.addEventListener('click', () => this.#onToggle())

    shadow.append(this.#backdrop, this.#specimens, this.#toggleButton)

    // 初期は非表示（背景と specimen を隠す）。トグルボタンは常時表示のため :host([hidden]) は使わず個別制御する。
    this.hide()
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
  }

  reset() {
    this.#specimens.replaceChildren()
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
