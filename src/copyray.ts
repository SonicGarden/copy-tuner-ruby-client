import CopyTunerBar from './copytuner_bar'
import Specimen from './specimen'

const findBlurbs = () =>
  Array.from(document.querySelectorAll('[data-copyray-key]')).map((element) => ({
    // 1 要素に複数キーがカンマ区切りで入りうる（同一テキストノードに複数訳文が連結された場合）
    keys: (element.getAttribute('data-copyray-key') ?? '').split(',').filter(Boolean),
    element,
  }))

export default class Copyray {
  // @ts-expect-error TS7006
  constructor(baseUrl, data, keysSkipped = false) {
    // @ts-expect-error TS2339
    this.baseUrl = baseUrl
    // @ts-expect-error TS2339
    this.data = data
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
    this.copyTunerBar = new CopyTunerBar(document.querySelector('#copy-tuner-bar'), this.data, this.boundOpen, keysSkipped)
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
    for (const { element, keys } of findBlurbs()) {
      // @ts-expect-error TS2339
      this.specimens.push(new Specimen(element, keys, this.boundOpen))
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
