import { OVERLAY_STYLES } from './styles'

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
  #boxes = new Map<Element, HTMLDivElement>()
  #frame: number | null = null

  constructor() {
    super()
    const shadow = this.attachShadow({ mode: 'open' })

    const style = document.createElement('style')
    style.textContent = OVERLAY_STYLES
    shadow.append(style)

    this.#backdrop = document.createElement('div')
    this.#backdrop.classList.add('backdrop')
    this.#backdrop.addEventListener('click', () => this.#onClose())

    this.#specimens = document.createElement('div')

    shadow.append(this.#backdrop, this.#specimens)
  }

  set onOpen(callback: OpenCallback) {
    this.#onOpen = callback
  }

  set onClose(callback: () => void) {
    this.#onClose = callback
  }

  show() {
    // 二重 show でもリスナーと boxes が重複しないよう、まず後始末を通す
    this.hide()

    for (const { element, keys } of findBlurbs()) {
      this.#boxes.set(element, this.makeBox(keys))
    }
    // 初回は同期で配置する（rAF 経由だと開いた直後の 1 フレームだけ位置がずれる）
    this.#reposition()
    this.#specimens.append(...this.#boxes.values())

    document.addEventListener('scroll', this.#requestReposition, { capture: true, passive: true })
    window.addEventListener('resize', this.#requestReposition, { passive: true })
  }

  hide() {
    // capture フラグはリスナーの同一性判定に含まれるため、省くと解除されない
    document.removeEventListener('scroll', this.#requestReposition, { capture: true })
    window.removeEventListener('resize', this.#requestReposition)

    // 閉じた後に走っても boxes は空で no-op になるが、無駄なコールバックを残さない
    if (this.#frame !== null) {
      cancelAnimationFrame(this.#frame)
      this.#frame = null
    }

    // detached な box を握り続けると開くたびに肥大する
    this.#boxes.clear()
    this.#specimens.replaceChildren()
  }

  // scroll は慣性スクロール中に毎フレーム相当で発火するため、同一フレーム内の再計測は 1 回にまとめる
  #requestReposition = () => {
    if (this.#frame !== null) return

    this.#frame = requestAnimationFrame(() => {
      this.#frame = null
      this.#reposition()
    })
  }

  #reposition() {
    // 読みと書きを分けないと、要素数分の強制同期レイアウトが走る
    const measured = Array.from(this.#boxes, ([element, box]) => [box, element.getBoundingClientRect()] as const)

    for (const [box, rect] of measured) {
      // display: none / DOM から外れた要素は rect が全て 0 になる。原点に枠だけ残さないよう隠す
      box.hidden = rect.width === 0 && rect.height === 0
      if (box.hidden) continue

      box.style.left = `${rect.left}px`
      box.style.top = `${rect.top}px`
      box.style.width = `${rect.width}px`
      box.style.height = `${rect.height}px`
    }
  }

  private makeBox(keys: string[]): HTMLDivElement {
    const box = document.createElement('div')
    box.classList.add('specimen')

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
