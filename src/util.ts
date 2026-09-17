const isMac = navigator.platform.toUpperCase().includes('MAC')

// @ts-expect-error TS7006
const isVisible = (element) => !!(element.offsetWidth || element.offsetHeight || element.getClientRects().length > 0)

// viewport 座標からページ座標への補正量。specimen の配置とコンテナのスクロール打ち消しで
// 同じ式を使わないと、clientTop/clientLeft が非ゼロのときに両者がずれる
const getScrollOffset = () => ({
  top: window.pageYOffset - document.documentElement.clientTop,
  left: window.pageXOffset - document.documentElement.clientLeft,
})

// @ts-expect-error TS7006
const getOffset = (elment) => {
  const box = elment.getBoundingClientRect()
  const scroll = getScrollOffset()

  return {
    top: box.top + scroll.top,
    left: box.left + scroll.left,
  }
}

// モーダル dialog の中身は top layer 上で viewport 基準に配置されるため、position: fixed と同じ扱いにする。
// fixed は祖先にあれば子孫も viewport に追従するので祖先方向も見るが、全祖先を辿ると
// 要素数 × DOM 深さ分の getComputedStyle になる。offsetParent は positioned な祖先だけを辿り、
// fixed 要素では null になって止まるため、走査を positioned 祖先の数（通常 1〜3）に抑えられる
const isViewportAnchored = (element: Element) => {
  if (element.closest('dialog:modal') !== null) return true

  for (let node: Element | null = element; node !== null; ) {
    if (getComputedStyle(node).position === 'fixed') return true
    node = node instanceof HTMLElement ? node.offsetParent : null
  }
  return false
}

// @ts-expect-error TS7006
const computeBoundingBox = (element) => {
  if (!isVisible(element)) {
    return null
  }

  const boxFrame = getOffset(element)
  // @ts-expect-error TS2339
  boxFrame.right = boxFrame.left + element.offsetWidth
  // @ts-expect-error TS2339
  boxFrame.bottom = boxFrame.top + element.offsetHeight

  return {
    left: boxFrame.left,
    top: boxFrame.top,
    // @ts-expect-error TS2339
    width: boxFrame.right - boxFrame.left,
    // @ts-expect-error TS2339
    height: boxFrame.bottom - boxFrame.top,
  }
}

const debounce = <A extends unknown[]>(fn: (...args: A) => void, wait: number) => {
  let timer: ReturnType<typeof setTimeout> | undefined
  return (...args: A) => {
    clearTimeout(timer)
    timer = setTimeout(() => fn(...args), wait)
  }
}

export { computeBoundingBox, debounce, getOffset, getScrollOffset, isMac, isViewportAnchored, isVisible }
