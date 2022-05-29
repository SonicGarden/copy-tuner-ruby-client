const isMac = navigator.userAgent.toUpperCase().includes('MAC')

const isVisible = (element: HTMLElement) =>
  !!(element.offsetWidth || element.offsetHeight || element.getClientRects().length > 0)

const getOffset = (element: HTMLElement) => {
  const box = element.getBoundingClientRect()

  return {
    top: box.top + (window.pageYOffset - document.documentElement.clientTop),
    left: box.left + (window.pageXOffset - document.documentElement.clientLeft),
  }
}

const computeBoundingBox = (element: HTMLElement) => {
  if (!isVisible(element)) {
    return
  }

  const boxFrame = getOffset(element)
  const right = boxFrame.left + element.offsetWidth
  const bottom = boxFrame.top + element.offsetHeight

  return {
    left: boxFrame.left,
    top: boxFrame.top,
    width: right - boxFrame.left,
    height: bottom - boxFrame.top,
  }
}

export { isMac, isVisible, getOffset, computeBoundingBox }
