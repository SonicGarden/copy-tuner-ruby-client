import { html, css, LitElement } from 'lit'
import { customElement, property } from 'lit/decorators.js'
import { StyleInfo, styleMap } from 'lit/directives/style-map.js'

@customElement('copyray-specimen')
export class CopyraySpecimen extends LitElement {
  static styles = css`
    .specimen {
      position: fixed;
      outline: 1px solid rgba(255, 255, 255, 0.8);
      outline-offset: -1px;
      outline: 1px solid rgba(255, 50, 50, 0.8);
      background: rgba(255, 50, 50, 0.1);
      font-family: 'Helvetica Neue', sans-serif;
      font-size: 13px;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.7);
      z-index: 2000000000;
    }
    .specimen:hover {
      cursor: pointer;
      background: rgba(255, 50, 50, 0.4);
    }
    .handle {
      position: absolute;
      top: 0;
      left: 0;
      background: rgba(255, 50, 50, 0.8);
      color: #fff;
      padding: 0 3px;
      font-size: 12px;
    }
  `

  @property({ attribute: false })
  target?: HTMLElement

  @property()
  key = ''

  render() {
    return html`
      <div class="specimen" style=${styleMap(this.styles())}>
        <span class="handle">${this.key}</span>
      </div>
    `
  }

  private styles(): StyleInfo {
    if (!this.target) return {}

    const rect = this.target.getBoundingClientRect()
    const styles = (['left', 'top', 'width', 'height'] as const).map((key) => [key, `${rect[key]}px`])
    return Object.fromEntries(styles)
  }
}
