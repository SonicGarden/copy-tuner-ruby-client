import { ROOT_STYLES } from './styles'

// dialog を showModal() で top layer の最上位に載せることで、アプリ側のモーダル dialog による
// inert 化を受けずに操作できる。トグルボタンだけ dialog の外に置くのは、
// 閉じている間 dialog のサブツリーが display: none になり、常時表示のボタンが消えてしまうため。
export class CopytunerRoot extends HTMLElement {
  readonly dialog: HTMLDialogElement
  #onToggle: () => void = () => {}

  constructor() {
    super()
    const shadow = this.attachShadow({ mode: 'open' })

    const style = document.createElement('style')
    style.textContent = ROOT_STYLES
    shadow.append(style)

    this.dialog = document.createElement('dialog')

    const toggleButton = document.createElement('a')
    toggleButton.classList.add('toggle-button')
    toggleButton.textContent = 'Open CopyTuner'
    toggleButton.addEventListener('click', () => this.#onToggle())

    shadow.append(this.dialog, toggleButton)
  }

  set onToggle(callback: () => void) {
    this.#onToggle = callback
  }
}
