import CopyTunerBar from './copytuner_bar'
import Specimen from './specimen'

// HTML コメントマーカー（<!--COPYRAY key-->）を走査する従来方式
const findBlurbsFromComments = () => {
  const filterNone = () => NodeFilter.FILTER_ACCEPT

  // @ts-expect-error TS2554
  const iterator = document.createNodeIterator(document.body, NodeFilter.SHOW_COMMENT, filterNone, false)

  const comments = []
  let curNode

  while ((curNode = iterator.nextNode())) {
    comments.push(curNode)
  }

  return (
    comments
      // @ts-expect-error TS2531
      .filter((comment) => comment.nodeValue.startsWith('COPYRAY'))
      .map((comment) => {
        // @ts-expect-error TS2488
        const [, key] = comment.nodeValue.match(/^COPYRAY (\S*)$/)
        const element = comment.parentNode
        return { key, element }
      })
  )
}

// subliminal（不可視文字）マーカーを走査する方式。
// ZWNJ(U+200C)=bit0, ZWJ(U+200D)=bit1。1 バイト = 9 不可視文字（8bit + 区切り 0, MSB first）。
const INVISIBLE = ['‌', '‍']
const INVISIBLE_RUN = /[‌‍]+/g

const decodeSubliminal = (run: string): string => {
  const bits = Array.from(run)
    .map((char: string) => INVISIBLE.indexOf(char))
    .join('')
  const bytes = (bits.match(/.{9}/g) ?? []).map((chunk: string) => parseInt(chunk.slice(0, 8), 2))
  return new TextDecoder().decode(new Uint8Array(bytes))
}

const findBlurbsFromSubliminal = () => {
  const filterNone = () => NodeFilter.FILTER_ACCEPT

  // @ts-expect-error TS2554
  const iterator = document.createNodeIterator(document.body, NodeFilter.SHOW_TEXT, filterNone, false)

  const result = []
  let curNode

  while ((curNode = iterator.nextNode())) {
    const runs = (curNode.nodeValue ?? '').match(INVISIBLE_RUN)
    if (!runs) continue

    for (const run of runs) {
      if (run.length % 9 !== 0) continue // 9bit 境界でないノイズを除外
      const key = decodeSubliminal(run)
      if (key) result.push({ key, element: curNode.parentNode })
    }
  }

  return result
}

const findBlurbs = (markerType?: string) => {
  return markerType === 'subliminal' ? findBlurbsFromSubliminal() : findBlurbsFromComments()
}

export default class Copyray {
  // @ts-expect-error TS7006
  constructor(baseUrl, data, markerType) {
    // @ts-expect-error TS2339
    this.baseUrl = baseUrl
    // @ts-expect-error TS2339
    this.data = data
    // @ts-expect-error TS2339
    this.markerType = markerType
    // @ts-expect-error TS2339
    this.isShowing = false
    // @ts-expect-error TS2339
    this.specimens = []
    // @ts-expect-error TS2339
    this.overlay = this.makeOverlay()
    // @ts-expect-error TS2339
    this.toggleButton = this.makeToggleButton()
    // @ts-expect-error TS2339
    this.boundOpen = this.open.bind(this)

    // @ts-expect-error TS2339
    this.copyTunerBar = new CopyTunerBar(document.querySelector('#copy-tuner-bar'), this.data, this.boundOpen)
  }

  show() {
    this.reset()

    // @ts-expect-error TS2339
    document.body.append(this.overlay)
    this.makeSpecimens()

    // @ts-expect-error TS2339
    for (const specimen of this.specimens) {
      specimen.show()
    }

    // @ts-expect-error TS2339
    this.copyTunerBar.show()
    // @ts-expect-error TS2339
    this.isShowing = true
  }

  hide() {
    // @ts-expect-error TS2339
    this.overlay.remove()
    this.reset()
    // @ts-expect-error TS2339
    this.copyTunerBar.hide()
    // @ts-expect-error TS2339
    this.isShowing = false
  }

  toggle() {
    // @ts-expect-error TS2339
    if (this.isShowing) {
      this.hide()
    } else {
      this.show()
    }
  }

  // @ts-expect-error TS7006
  open(key) {
    // @ts-expect-error TS2339
    window.open(`${this.baseUrl}/blurbs/${key}/edit`)
  }

  makeSpecimens() {
    // @ts-expect-error TS2339
    for (const { element, key } of findBlurbs(this.markerType)) {
      // @ts-expect-error TS2339
      this.specimens.push(new Specimen(element, key, this.boundOpen))
    }
  }

  makeToggleButton() {
    const element = document.createElement('a')

    element.addEventListener('click', () => {
      this.show()
    })

    element.classList.add('copyray-toggle-button')
    element.classList.add('hidden-on-mobile')
    element.textContent = 'Open CopyTuner'
    document.body.append(element)

    return element
  }

  makeOverlay() {
    const div = document.createElement('div')
    div.setAttribute('id', 'copyray-overlay')
    div.addEventListener('click', () => this.hide())
    return div
  }

  reset() {
    // @ts-expect-error TS2339
    for (const specimen of this.specimens) {
      specimen.remove()
    }
  }
}
