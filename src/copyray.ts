import { CopytunerBar, type CopytunerData } from './copytuner_bar'
import { CopyraySpecimen } from './specimen'

export { type CopytunerData } from './copytuner_bar'

const COPYRAY_PREFIX = 'COPYRAY'

const findCopyrayComments = (): readonly Comment[] => {
  const filterNone: NodeFilter = (node) => {
    return node.nodeValue?.startsWith(COPYRAY_PREFIX) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT
  }
  const iterator = document.createNodeIterator(document.body, NodeFilter.SHOW_COMMENT, filterNone)

  const comments: Comment[] = []
  let curNode

  while ((curNode = iterator.nextNode())) {
    comments.push(curNode as Comment)
  }

  return comments
}

type Blurb = {
  key: string
  element: HTMLElement
}

const findBlurbs = (): readonly Blurb[] => {
  return findCopyrayComments().map((comment) => {
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    const key = comment.nodeValue!.replace(COPYRAY_PREFIX, '').trim()
    const element = comment.parentNode as HTMLElement
    return { key, element }
  })
}

export class Copyray {
  public isShowing: boolean

  private baseUrl: string
  private data: CopytunerData
  private copyTunerBar: CopytunerBar
  private boundOpen: Copyray['open']
  private overlay: HTMLDivElement
  private specimens: CopyraySpecimen[]

  constructor(baseUrl: string, data: CopytunerData) {
    this.baseUrl = baseUrl
    this.data = data
    this.isShowing = false
    this.specimens = []
    this.overlay = this.makeOverlay()
    this.boundOpen = this.open.bind(this)
    this.copyTunerBar = new CopytunerBar(
      // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
      document.querySelector<HTMLDivElement>('#copy-tuner-bar')!,
      this.data,
      this.boundOpen,
    )

    this.appendToggleButton()
  }

  show() {
    this.reset()
    document.body.append(this.overlay)
    this.makeSpecimens()

    for (const specimen of this.specimens) {
      document.body.append(specimen)
    }

    this.copyTunerBar.show()
    this.isShowing = true
  }

  hide() {
    this.overlay.remove()
    this.reset()
    this.copyTunerBar.hide()
    this.isShowing = false
  }

  toggle() {
    if (this.isShowing) {
      this.hide()
    } else {
      this.show()
    }
  }

  open(key: string) {
    window.open(`${this.baseUrl}/blurbs/${key}/edit`)
  }

  makeSpecimens() {
    for (const { element, key } of findBlurbs()) {
      const specimen = new CopyraySpecimen()
      specimen.key = key
      specimen.target = element
      specimen.addEventListener('click', () => {
        this.open(key)
      })
      this.specimens.push(specimen)
    }
  }

  appendToggleButton() {
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
    for (const specimen of this.specimens) {
      specimen.remove()
    }

    this.specimens = []
  }
}
