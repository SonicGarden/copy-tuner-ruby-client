import { debounce } from 'mabiki'

export type CopytunerData = Record<string, string>

const HIDDEN_CLASS = 'copy-tuner-hidden'

type Open = (key: string) => void

export class CopytunerBar {
  private callback: Open
  private element: HTMLElement
  private data: CopytunerData
  private searchBoxElement: HTMLDivElement
  private logMenuElement: HTMLDivElement

  constructor(element: HTMLElement, data: CopytunerData, callback: Open) {
    this.element = element
    this.data = data
    this.callback = callback
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    this.searchBoxElement = element.querySelector<HTMLDivElement>('.js-copy-tuner-bar-search')!
    this.logMenuElement = this.makeLogMenu()
    this.element.append(this.logMenuElement)

    this.addHandler()
  }

  addHandler() {
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    const openLogButton = this.element.querySelector<HTMLElement>('.js-copy-tuner-bar-open-log')!
    openLogButton.addEventListener('click', (event) => {
      event.preventDefault()
      this.toggleLogMenu()
    })

    this.searchBoxElement.addEventListener('input', debounce(this.onInput.bind(this), 250))
  }

  show() {
    this.element.classList.remove(HIDDEN_CLASS)
    this.searchBoxElement.focus()
  }

  hide() {
    this.element.classList.add(HIDDEN_CLASS)
  }

  showLogMenu() {
    this.logMenuElement.classList.remove(HIDDEN_CLASS)
  }

  toggleLogMenu() {
    this.logMenuElement.classList.toggle(HIDDEN_CLASS)
  }

  makeLogMenu(): HTMLDivElement {
    const div = document.createElement('div')
    div.setAttribute('id', 'copy-tuner-bar-log-menu')
    div.classList.add(HIDDEN_CLASS)

    const table = document.createElement('table')
    const tbody = document.createElement('tbody')
    tbody.classList.remove('is-not-initialized')

    for (const key of Object.keys(this.data).sort()) {
      const value = this.data[key]

      if (value === '') {
        continue
      }

      const td1 = document.createElement('td')
      td1.textContent = key
      const td2 = document.createElement('td')
      td2.textContent = value
      const tr = document.createElement('tr')
      tr.classList.add('copy-tuner-bar-log-menu__row')
      tr.dataset.key = key

      tr.addEventListener('click', (event) => {
        // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
        this.callback((event.currentTarget as HTMLElement).dataset.key!)
      })

      tr.append(td1)
      tr.append(td2)
      tbody.append(tr)
    }

    table.append(tbody)
    div.append(table)

    return div
  }

  onInput(event: Event): void {
    const keyword = (event.target as HTMLInputElement).value.trim()
    this.showLogMenu()

    const rows = [...this.logMenuElement.querySelectorAll<HTMLTableRowElement>('tr')]

    for (const row of rows) {
      const isShow = keyword === '' || [...row.querySelectorAll('td')].some((td) => td.textContent?.includes(keyword))
      row.classList.toggle(HIDDEN_CLASS, !isShow)
    }
  }
}
