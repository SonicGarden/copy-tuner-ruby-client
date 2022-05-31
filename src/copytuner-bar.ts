import { html, css, LitElement } from 'lit'
import { customElement, property, state } from 'lit/decorators.js'
import { createRef, Ref, ref } from 'lit/directives/ref.js'

export type CopytunerData = Record<string, string>

export type Blurb = { key: string; content: string }

@customElement('copytuner-bar')
export class CopytunerBar extends LitElement {
  static styles = css`
    [hidden] {
      display: none !important;
    }

    .bar {
      position: fixed;
      left: 0;
      right: 0;
      bottom: 0;
      height: 40px;
      padding: 0 8px;
      background: #222;
      font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
      font-weight: 200;
      color: #fff;
      z-index: 2147483647;
      box-shadow: 0 -1px 0 rgba(255, 255, 255, 0.1), inset 0 2px 6px rgba(0, 0, 0, 0.8);
      background-image: linear-gradient(rgba(0, 0, 0, 0), rgba(0, 0, 0, 0.3));
    }

    .log-menu {
      position: fixed;
      left: 0;
      right: 0;
      bottom: 40px;
      max-height: calc(100vh - 40px);
      background: #222;
      font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
      color: #fff;
      z-index: 2147483647;
      overflow-y: auto;
    }

    .btn {
      position: relative;
      display: inline-block;
      color: #fff;
      margin: 8px 1px;
      height: 24px;
      line-height: 24px;
      padding: 0 8px;
      font-size: 14px;
      cursor: pointer;
      vertical-align: middle;
      background-color: #444;
      background-image: linear-gradient(rgba(0, 0, 0, 0), rgba(0, 0, 0, 0.2));
      border-radius: 2px;
      box-shadow: 1px 1px 1px rgba(0, 0, 0, 0.5), inset 0 1px 0 rgba(255, 255, 255, 0.2),
        inset 0 0 2px rgba(255, 255, 255, 0.2);
      text-shadow: 0 -1px 0 rgba(0, 0, 0, 0.4);
    }

    input-search {
      -webkit-appearance: none;
      -moz-appearance: none;
      appearance: none;
      border: none;
      border-radius: 2px;
      background-image: linear-gradient(rgba(0, 0, 0, 0.2), rgba(0, 0, 0, 0));
      box-shadow: inset 0 1px 0 rgba(0, 0, 0, 0.2), inset 0 0 2px rgba(0, 0, 0, 0.2);
      padding: 2px 8px;
      margin: 0;
      line-height: 20px;
      vertical-align: middle;
      color: black;
      width: auto;
      height: auto;
      font-size: 14px;
    }
  `

  @property()
  url = '/'

  @state()
  isShow = false

  @state()
  query = ''

  @property({ attribute: false })
  blurbs: readonly Blurb[] = []

  inputRef: Ref<HTMLInputElement> = createRef()

  firstUpdated() {
    this.inputRef.value?.focus()
  }

  render() {
    return html`
      <div class="bar">
        <a class="btn" target="_blank" href="${this.url}">CopyTuner</a>
        <a href="/copytuner" target="_blank" class="btn">Sync</a>
        <button type="button" class="btn" @click=${this.toggle}>Translations in this page</button>
        <input type="text" class="input-search" placeholder="search" ${ref(this.inputRef)} @input=${this._onInput} />
        <div class="log-menu" ?hidden=${!this.isShow}>
          <table>
            <tbody>
              ${this._filteredBlurbs().map(
                (blurb) => html`
                  <tr data-key=${blurb.key} @click=${this._onClickKey}>
                    <td>${blurb.key}</td>
                    <td>${blurb.content}</td>
                  </tr>
                `,
              )}
            </tbody>
          </table>
        </div>
      </div>
    `
  }

  toggle() {
    this.isShow ? this.hide() : this.show()
  }

  show() {
    this.isShow = true
    this.inputRef.value?.focus()
  }

  hide() {
    this.isShow = false
  }

  private _filteredBlurbs() {
    return this.blurbs.filter(({ key, content }) => [key, content].some((str) => str.includes(this.query)))
  }

  private _onInput = (event: Event) => {
    this.query = (event.target as HTMLInputElement).value.trim()
    this.show()
  }

  private _onClickKey = (event: MouseEvent) => {
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    const key = (event.currentTarget as HTMLElement).dataset.key!
    window.open(`${this.url}/blurbs/${key}/edit`)
  }
}
