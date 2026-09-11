// dialog.showModal() のモーダルは top layer に描画され z-index では上に出られないため、
// オーバーレイ側も popover として top layer に載せる（top layer 内は後から表示したものが上になる）。

const supportsPopover = () => typeof HTMLElement.prototype.showPopover === 'function'

export const promoteToTopLayer = (element: HTMLElement) => {
  if (!supportsPopover()) return
  element.setAttribute('popover', 'manual')
}

// popover 属性が残っていると閉じている間 display: none になり、常時表示のトグルボタンごと消えるため
export const demoteFromTopLayer = (element: HTMLElement) => {
  element.removeAttribute('popover')
}

export const showOnTopLayer = (element: HTMLElement) => {
  if (element.hasAttribute('popover') && element.isConnected && !element.matches(':popover-open')) {
    element.showPopover()
  }
}

export const hideFromTopLayer = (element: HTMLElement) => {
  if (element.hasAttribute('popover') && element.isConnected && element.matches(':popover-open')) {
    element.hidePopover()
  }
}

// モーダルdialogの表示中はdialogのサブツリー以外がinertになり、top layer上でもクリックできないため
export const topLayerHost = (): HTMLElement => {
  if (!supportsPopover()) return document.body

  const dialogs = [...document.querySelectorAll<HTMLDialogElement>('dialog[open]')]
  return dialogs.findLast((dialog) => dialog.matches(':modal')) ?? document.body
}
