import type { Copyray } from './copyray'
import { computeBoundingBox } from './util'

const ZINDEX = 2_000_000_000

export class Specimen {
  private element: HTMLElement
  private key: string
  private onOpen: (key: string) => void
  private box: HTMLDivElement | undefined

  constructor(element: HTMLElement, key: string, onOpen: Copyray['open']) {
    this.element = element
    this.key = key
    this.onOpen = onOpen
  }

  show() {
    this.box = this.makeBox()
    if (!this.box) return

    this.box.addEventListener('click', () => {
      this.onOpen(this.key)
    })

    document.body.append(this.box)
  }

  remove() {
    if (!this.box) {
      return
    }
    this.box.remove()
    this.box = undefined
  }

  makeBox(): HTMLDivElement | undefined {
    const box = document.createElement('div')
    box.classList.add('copyray-specimen')
    box.classList.add('Specimen')

    const bounds = computeBoundingBox(this.element)
    if (!bounds) return

    for (const key of ['left', 'top', 'width', 'height'] as const) {
      const value = bounds[key]
      box.style[key] = `${value}px`
    }
    box.style.zIndex = ZINDEX.toString()

    const { position, top, left } = getComputedStyle(this.element)
    if (this.box && position === 'fixed') {
      this.box.style.position = 'fixed'
      this.box.style.top = `${top}px`
      this.box.style.left = `${left}px`
    }

    box.append(this.makeLabel())
    return box
  }

  makeLabel() {
    const div = document.createElement('div')
    div.classList.add('copyray-specimen-handle')
    div.classList.add('Specimen')
    div.textContent = this.key
    return div
  }
}
