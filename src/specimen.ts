import { computeBoundingBox } from './util'

const ZINDEX = 2_000_000_000

export default class Specimen {
  // @ts-expect-error TS7006
  constructor(element, keys, callback) {
    // @ts-expect-error TS2339
    this.element = element
    // @ts-expect-error TS2339
    this.keys = keys
    // @ts-expect-error TS2339
    this.callback = callback
  }

  show() {
    // @ts-expect-error TS2339
    this.box = this.makeBox()
    // @ts-expect-error TS2339
    if (this.box === null) return

    // box 全体のクリックは先頭キーを開く（広いクリック領域を維持）。複数キー時は各ラベルから個別に開ける
    // @ts-expect-error TS2339
    this.box.addEventListener('click', () => {
      // @ts-expect-error TS2339
      this.callback(this.keys[0])
    })

    // @ts-expect-error TS2339
    document.body.append(this.box)
  }

  remove() {
    // @ts-expect-error TS2339
    if (!this.box) {
      return
    }
    // @ts-expect-error TS2339
    this.box.remove()
    // @ts-expect-error TS2339
    this.box = null
  }

  makeBox() {
    const box = document.createElement('div')
    box.classList.add('copyray-specimen')
    box.classList.add('Specimen')

    // @ts-expect-error TS2339
    const bounds = computeBoundingBox(this.element)
    if (bounds === null) return null

    for (const key of Object.keys(bounds)) {
      // @ts-expect-error TS7053
      const value = bounds[key]
      // @ts-expect-error TS7015
      box.style[key] = `${value}px`
    }
    // @ts-expect-error TS2322
    box.style.zIndex = ZINDEX

    // @ts-expect-error TS2339
    const { position, top, left } = getComputedStyle(this.element)
    if (position === 'fixed') {
      // @ts-expect-error TS2339
      this.box.style.position = 'fixed'
      // @ts-expect-error TS2339
      this.box.style.top = `${top}px`
      // @ts-expect-error TS2339
      this.box.style.left = `${left}px`
    }

    // @ts-expect-error TS2339
    for (const key of this.keys) {
      box.append(this.makeLabel(key))
    }
    return box
  }

  // @ts-expect-error TS7006
  makeLabel(key) {
    const div = document.createElement('div')
    div.classList.add('copyray-specimen-handle')
    div.classList.add('Specimen')
    div.textContent = key
    // ラベルのクリックはそのキーを開く。box への伝播を止めて先頭キーとの二重発火を防ぐ
    div.addEventListener('click', (event) => {
      event.stopPropagation()
      // @ts-expect-error TS2339
      this.callback(key)
    })
    return div
  }
}
