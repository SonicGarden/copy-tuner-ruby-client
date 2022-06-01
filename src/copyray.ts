import { html, css, LitElement } from 'lit'
import { customElement, property, state } from 'lit/decorators.js'
import { Blurb } from './copytuner-bar'
import { CopyraySpecimen } from './specimen'
import { isMac } from './util'

export { type CopytunerData } from './copytuner-bar'

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

type KeyElement = {
  key: string
  element: HTMLElement
}

const findKeyElements = (): readonly KeyElement[] => {
  return findCopyrayComments().map((comment) => {
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    const key = comment.nodeValue!.replace(COPYRAY_PREFIX, '').trim()
    const element = comment.parentNode as HTMLElement
    return { key, element }
  })
}

@customElement('copytuner-inspector')
export class CopytunerInspector extends LitElement {
  static styles = css`
    [hidden] {
      display: none !important;
    }

    .button {
      display: block;
      position: fixed;
      left: 0;
      bottom: 0;
      color: white;
      background: black;
      padding: 12px 16px;
      border-radius: 0 10px 0 0;
      opacity: 0;
      transition: opacity 0.6s ease-in-out;
      z-index: 10000;
      font-size: 12px;
      cursor: pointer;
    }

    .button:hover {
      opacity: 1;
    }

    .overlay {
      position: fixed;
      left: 0;
      top: 0;
      bottom: 0;
      right: 0;
      background-image: radial-gradient(
        ellipse farthest-corner at center,
        rgba(0, 0, 0, 0.4) 10%,
        rgba(0, 0, 0, 0.8) 100%
      );
      z-index: 9000;
    }
  `

  @property()
  url = '/'

  @property({ attribute: false })
  blurbs: readonly Blurb[] = []

  @state()
  isShowing = false

  connectedCallback(): void {
    super.connectedCallback()
    if (console) {
      // eslint-disable-next-line no-console
      console.log(`Ready to Copyray. Press ${isMac ? 'cmd+shift+k' : 'ctrl+shift+k'} to scan your UI.`)
    }

    document.body.addEventListener('keydown', this._handleKeyDown)
  }

  render() {
    return html`
      <button type="button" class="button" @click=${this.toggle}>Open CopyTuner</button>
      <div ?hidden=${!this.isShowing}>
        <copytuner-bar url=${this.url} .blurbs=${this.blurbs}></copytuner-bar>
        <div class="overlay" @click=${this.hide}></div>
      </div>
    `
  }

  toggle() {
    this.isShowing ? this.hide() : this.show()
  }

  show() {
    this.isShowing = true
    this._appendSpecimens()
  }

  hide() {
    for (const specimen of document.body.querySelectorAll('copyray-specimen')) {
      specimen.remove()
    }
    this.isShowing = false
  }

  openKeyEditor(key: string) {
    window.open(`${this.url}/blurbs/${key}/edit`)
  }

  private _appendSpecimens() {
    for (const { element, key } of findKeyElements()) {
      const specimen = new CopyraySpecimen()
      specimen.key = key
      specimen.target = element
      specimen.addEventListener('click', () => {
        this.openKeyEditor(key)
      })
      document.body.append(specimen)
    }
  }

  private _handleKeyDown = (event: KeyboardEvent) => {
    if (this.isShowing && ['Escape', 'Esc'].includes(event.key)) {
      this.hide()
      return
    }

    if (((isMac && event.metaKey) || (!isMac && event.ctrlKey)) && event.shiftKey && event.key === 'k') {
      this.toggle()
    }
  }
}
