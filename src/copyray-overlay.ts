import { OVERLAY_STYLES } from './styles'
import { computeBoundingBox, getScrollOffset, isViewportAnchored } from './util'

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

// オーバーレイ背景と翻訳要素のハイライト枠（specimen）を Shadow DOM 内に描画する。
export class CopyrayOverlay extends HTMLElement {
  #onOpen: OpenCallback = () => {}
  #onClose: () => void = () => {}
  #backdrop: HTMLDivElement
  #specimens: HTMLDivElement
  #scrollFrame: number | null = null

  constructor() {
    super()
    const shadow = this.attachShadow({ mode: 'open' })

    const style = document.createElement('style')
    style.textContent = OVERLAY_STYLES
    shadow.append(style)

    this.#backdrop = document.createElement('div')
    this.#backdrop.classList.add('backdrop')
    this.#backdrop.addEventListener('click', () => this.#onClose())

    // specimen をページ座標基準で absolute 配置するコンテナ
    this.#specimens = document.createElement('div')
    this.#specimens.classList.add('specimens')

    shadow.append(this.#backdrop, this.#specimens)
  }

  set onOpen(callback: OpenCallback) {
    this.#onOpen = callback
  }

  set onClose(callback: () => void) {
    this.#onClose = callback
  }

  show() {
    this.reset()
    // 初回は 1 フレームも待たせない（rAF 経由だと開いた直後の 1 フレームだけ位置がずれる）
    this.#applyScrollOffset()
    window.addEventListener('scroll', this.#syncScrollOffset, { passive: true })

    for (const { element, keys } of findBlurbs()) {
      const box = this.makeBox(element, keys)
      if (box) {
        this.#specimens.append(box)
      }
    }
  }

  hide() {
    this.reset()
    window.removeEventListener('scroll', this.#syncScrollOffset)

    // 予約済みのフレームが閉じた後に走ると、次に開くまで残る位置ずれになる
    if (this.#scrollFrame !== null) {
      cancelAnimationFrame(this.#scrollFrame)
      this.#scrollFrame = null
    }
  }

  reset() {
    this.#specimens.replaceChildren()
  }

  // ホストは viewport 固定の dialog 内にあるため、スクロール量を打ち消してページ座標の原点に合わせる。
  // transform は使えない（.specimens が子孫の position: fixed の含有ブロックになり、fixed な specimen が壊れる）
  #applyScrollOffset() {
    const scroll = getScrollOffset()
    this.#specimens.style.top = `${-scroll.top}px`
    this.#specimens.style.left = `${-scroll.left}px`
  }

  // scroll は慣性スクロール中に毎フレーム相当で発火するため、同一フレーム内の書き込みは 1 回にまとめる
  #syncScrollOffset = () => {
    if (this.#scrollFrame !== null) return

    this.#scrollFrame = requestAnimationFrame(() => {
      this.#scrollFrame = null
      this.#applyScrollOffset()
    })
  }

  private makeBox(element: Element, keys: string[]): HTMLDivElement | null {
    const bounds = computeBoundingBox(element)
    if (bounds === null) return null

    const box = document.createElement('div')
    box.classList.add('specimen')
    box.style.width = `${bounds.width}px`
    box.style.height = `${bounds.height}px`

    if (isViewportAnchored(element)) {
      // ページ座標から補正量を引くと viewport 座標に戻る（getBoundingClientRect の再取得を避ける）
      const scroll = getScrollOffset()
      box.style.position = 'fixed'
      box.style.left = `${bounds.left - scroll.left}px`
      box.style.top = `${bounds.top - scroll.top}px`
    } else {
      box.style.left = `${bounds.left}px`
      box.style.top = `${bounds.top}px`
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
