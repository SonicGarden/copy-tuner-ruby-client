var commonjsGlobal = typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : {};
var KeyCode = {};
KeyCode.KEY_CANCEL = 3;
KeyCode.KEY_HELP = 6;
KeyCode.KEY_BACK_SPACE = 8;
KeyCode.KEY_TAB = 9;
KeyCode.KEY_CLEAR = 12;
KeyCode.KEY_RETURN = 13;
KeyCode.KEY_ENTER = 14;
KeyCode.KEY_SHIFT = 16;
KeyCode.KEY_CONTROL = 17;
KeyCode.KEY_ALT = 18;
KeyCode.KEY_PAUSE = 19;
KeyCode.KEY_CAPS_LOCK = 20;
KeyCode.KEY_ESCAPE = 27;
KeyCode.KEY_SPACE = 32;
KeyCode.KEY_PAGE_UP = 33;
KeyCode.KEY_PAGE_DOWN = 34;
KeyCode.KEY_END = 35;
KeyCode.KEY_HOME = 36;
KeyCode.KEY_LEFT = 37;
KeyCode.KEY_UP = 38;
KeyCode.KEY_RIGHT = 39;
KeyCode.KEY_DOWN = 40;
KeyCode.KEY_PRINTSCREEN = 44;
KeyCode.KEY_INSERT = 45;
KeyCode.KEY_DELETE = 46;
KeyCode.KEY_0 = 48;
KeyCode.KEY_1 = 49;
KeyCode.KEY_2 = 50;
KeyCode.KEY_3 = 51;
KeyCode.KEY_4 = 52;
KeyCode.KEY_5 = 53;
KeyCode.KEY_6 = 54;
KeyCode.KEY_7 = 55;
KeyCode.KEY_8 = 56;
KeyCode.KEY_9 = 57;
KeyCode.KEY_SEMICOLON = 59;
KeyCode.KEY_EQUALS = 61;
KeyCode.KEY_A = 65;
KeyCode.KEY_B = 66;
KeyCode.KEY_C = 67;
KeyCode.KEY_D = 68;
KeyCode.KEY_E = 69;
KeyCode.KEY_F = 70;
KeyCode.KEY_G = 71;
KeyCode.KEY_H = 72;
KeyCode.KEY_I = 73;
KeyCode.KEY_J = 74;
KeyCode.KEY_K = 75;
KeyCode.KEY_L = 76;
KeyCode.KEY_M = 77;
KeyCode.KEY_N = 78;
KeyCode.KEY_O = 79;
KeyCode.KEY_P = 80;
KeyCode.KEY_Q = 81;
KeyCode.KEY_R = 82;
KeyCode.KEY_S = 83;
KeyCode.KEY_T = 84;
KeyCode.KEY_U = 85;
KeyCode.KEY_V = 86;
KeyCode.KEY_W = 87;
KeyCode.KEY_X = 88;
KeyCode.KEY_Y = 89;
KeyCode.KEY_Z = 90;
KeyCode.KEY_LEFT_CMD = 91;
KeyCode.KEY_RIGHT_CMD = 93;
KeyCode.KEY_CONTEXT_MENU = 93;
KeyCode.KEY_NUMPAD0 = 96;
KeyCode.KEY_NUMPAD1 = 97;
KeyCode.KEY_NUMPAD2 = 98;
KeyCode.KEY_NUMPAD3 = 99;
KeyCode.KEY_NUMPAD4 = 100;
KeyCode.KEY_NUMPAD5 = 101;
KeyCode.KEY_NUMPAD6 = 102;
KeyCode.KEY_NUMPAD7 = 103;
KeyCode.KEY_NUMPAD8 = 104;
KeyCode.KEY_NUMPAD9 = 105;
KeyCode.KEY_MULTIPLY = 106;
KeyCode.KEY_ADD = 107;
KeyCode.KEY_SEPARATOR = 108;
KeyCode.KEY_SUBTRACT = 109;
KeyCode.KEY_DECIMAL = 110;
KeyCode.KEY_DIVIDE = 111;
KeyCode.KEY_F1 = 112;
KeyCode.KEY_F2 = 113;
KeyCode.KEY_F3 = 114;
KeyCode.KEY_F4 = 115;
KeyCode.KEY_F5 = 116;
KeyCode.KEY_F6 = 117;
KeyCode.KEY_F7 = 118;
KeyCode.KEY_F8 = 119;
KeyCode.KEY_F9 = 120;
KeyCode.KEY_F10 = 121;
KeyCode.KEY_F11 = 122;
KeyCode.KEY_F12 = 123;
KeyCode.KEY_F13 = 124;
KeyCode.KEY_F14 = 125;
KeyCode.KEY_F15 = 126;
KeyCode.KEY_F16 = 127;
KeyCode.KEY_F17 = 128;
KeyCode.KEY_F18 = 129;
KeyCode.KEY_F19 = 130;
KeyCode.KEY_F20 = 131;
KeyCode.KEY_F21 = 132;
KeyCode.KEY_F22 = 133;
KeyCode.KEY_F23 = 134;
KeyCode.KEY_F24 = 135;
KeyCode.KEY_NUM_LOCK = 144;
KeyCode.KEY_SCROLL_LOCK = 145;
KeyCode.KEY_COMMA = 188;
KeyCode.KEY_PERIOD = 190;
KeyCode.KEY_SLASH = 191;
KeyCode.KEY_BACK_QUOTE = 192;
KeyCode.KEY_OPEN_BRACKET = 219;
KeyCode.KEY_BACK_SLASH = 220;
KeyCode.KEY_CLOSE_BRACKET = 221;
KeyCode.KEY_QUOTE = 222;
KeyCode.KEY_META = 224;
var keycodeJs = KeyCode;
const isMac = navigator.platform.toUpperCase().indexOf("MAC") !== -1;
const isVisible = (element) => !!(element.offsetWidth || element.offsetHeight || element.getClientRects().length);
const getOffset = (elment) => {
  const box = elment.getBoundingClientRect();
  return {
    top: box.top + (window.pageYOffset - document.documentElement.clientTop),
    left: box.left + (window.pageXOffset - document.documentElement.clientLeft)
  };
};
const computeBoundingBox = (element) => {
  if (!isVisible(element)) {
    return null;
  }
  const boxFrame = getOffset(element);
  boxFrame.right = boxFrame.left + element.offsetWidth;
  boxFrame.bottom = boxFrame.top + element.offsetHeight;
  return {
    left: boxFrame.left,
    top: boxFrame.top,
    width: boxFrame.right - boxFrame.left,
    height: boxFrame.bottom - boxFrame.top
  };
};
const ZINDEX = 2e9;
class Specimen {
  constructor(element, key, callback) {
    this.element = element;
    this.key = key;
    this.callback = callback;
  }
  show() {
    this.box = this.makeBox();
    if (this.box === null)
      return;
    this.box.addEventListener("click", () => {
      this.callback(this.key);
    });
    document.body.appendChild(this.box);
  }
  remove() {
    if (!this.box) {
      return;
    }
    this.box.remove();
    this.box = null;
  }
  makeBox() {
    const box = document.createElement("div");
    box.classList.add("copyray-specimen");
    box.classList.add("Specimen");
    const bounds = computeBoundingBox(this.element);
    if (bounds === null)
      return null;
    Object.keys(bounds).forEach((key) => {
      const value = bounds[key];
      box.style[key] = `${value}px`;
    });
    box.style.zIndex = ZINDEX;
    const { position, top, left } = getComputedStyle(this.element);
    if (position === "fixed") {
      this.box.style.position = "fixed";
      this.box.style.top = `${top}px`;
      this.box.style.left = `${left}px`;
    }
    box.appendChild(this.makeLabel());
    return box;
  }
  makeLabel() {
    const div = document.createElement("div");
    div.classList.add("copyray-specimen-handle");
    div.classList.add("Specimen");
    div.textContent = this.key;
    return div;
  }
}
var FUNC_ERROR_TEXT = "Expected a function";
var NAN = 0 / 0;
var symbolTag = "[object Symbol]";
var reTrim = /^\s+|\s+$/g;
var reIsBadHex = /^[-+]0x[0-9a-f]+$/i;
var reIsBinary = /^0b[01]+$/i;
var reIsOctal = /^0o[0-7]+$/i;
var freeParseInt = parseInt;
var freeGlobal = typeof commonjsGlobal == "object" && commonjsGlobal && commonjsGlobal.Object === Object && commonjsGlobal;
var freeSelf = typeof self == "object" && self && self.Object === Object && self;
var root = freeGlobal || freeSelf || Function("return this")();
var objectProto = Object.prototype;
var objectToString = objectProto.toString;
var nativeMax = Math.max, nativeMin = Math.min;
var now = function() {
  return root.Date.now();
};
function debounce(func, wait, options) {
  var lastArgs, lastThis, maxWait, result, timerId, lastCallTime, lastInvokeTime = 0, leading = false, maxing = false, trailing = true;
  if (typeof func != "function") {
    throw new TypeError(FUNC_ERROR_TEXT);
  }
  wait = toNumber(wait) || 0;
  if (isObject(options)) {
    leading = !!options.leading;
    maxing = "maxWait" in options;
    maxWait = maxing ? nativeMax(toNumber(options.maxWait) || 0, wait) : maxWait;
    trailing = "trailing" in options ? !!options.trailing : trailing;
  }
  function invokeFunc(time) {
    var args = lastArgs, thisArg = lastThis;
    lastArgs = lastThis = void 0;
    lastInvokeTime = time;
    result = func.apply(thisArg, args);
    return result;
  }
  function leadingEdge(time) {
    lastInvokeTime = time;
    timerId = setTimeout(timerExpired, wait);
    return leading ? invokeFunc(time) : result;
  }
  function remainingWait(time) {
    var timeSinceLastCall = time - lastCallTime, timeSinceLastInvoke = time - lastInvokeTime, result2 = wait - timeSinceLastCall;
    return maxing ? nativeMin(result2, maxWait - timeSinceLastInvoke) : result2;
  }
  function shouldInvoke(time) {
    var timeSinceLastCall = time - lastCallTime, timeSinceLastInvoke = time - lastInvokeTime;
    return lastCallTime === void 0 || timeSinceLastCall >= wait || timeSinceLastCall < 0 || maxing && timeSinceLastInvoke >= maxWait;
  }
  function timerExpired() {
    var time = now();
    if (shouldInvoke(time)) {
      return trailingEdge(time);
    }
    timerId = setTimeout(timerExpired, remainingWait(time));
  }
  function trailingEdge(time) {
    timerId = void 0;
    if (trailing && lastArgs) {
      return invokeFunc(time);
    }
    lastArgs = lastThis = void 0;
    return result;
  }
  function cancel() {
    if (timerId !== void 0) {
      clearTimeout(timerId);
    }
    lastInvokeTime = 0;
    lastArgs = lastCallTime = lastThis = timerId = void 0;
  }
  function flush() {
    return timerId === void 0 ? result : trailingEdge(now());
  }
  function debounced() {
    var time = now(), isInvoking = shouldInvoke(time);
    lastArgs = arguments;
    lastThis = this;
    lastCallTime = time;
    if (isInvoking) {
      if (timerId === void 0) {
        return leadingEdge(lastCallTime);
      }
      if (maxing) {
        timerId = setTimeout(timerExpired, wait);
        return invokeFunc(lastCallTime);
      }
    }
    if (timerId === void 0) {
      timerId = setTimeout(timerExpired, wait);
    }
    return result;
  }
  debounced.cancel = cancel;
  debounced.flush = flush;
  return debounced;
}
function isObject(value) {
  var type = typeof value;
  return !!value && (type == "object" || type == "function");
}
function isObjectLike(value) {
  return !!value && typeof value == "object";
}
function isSymbol(value) {
  return typeof value == "symbol" || isObjectLike(value) && objectToString.call(value) == symbolTag;
}
function toNumber(value) {
  if (typeof value == "number") {
    return value;
  }
  if (isSymbol(value)) {
    return NAN;
  }
  if (isObject(value)) {
    var other = typeof value.valueOf == "function" ? value.valueOf() : value;
    value = isObject(other) ? other + "" : other;
  }
  if (typeof value != "string") {
    return value === 0 ? value : +value;
  }
  value = value.replace(reTrim, "");
  var isBinary = reIsBinary.test(value);
  return isBinary || reIsOctal.test(value) ? freeParseInt(value.slice(2), isBinary ? 2 : 8) : reIsBadHex.test(value) ? NAN : +value;
}
var lodash_debounce = debounce;
const HIDDEN_CLASS = "copy-tuner-hidden";
class CopytunerBar {
  constructor(element, data, callback) {
    this.element = element;
    this.data = data;
    this.callback = callback;
    this.searchBoxElement = element.querySelector(".js-copy-tuner-bar-search");
    this.logMenuElement = this.makeLogMenu();
    this.element.appendChild(this.logMenuElement);
    this.addHandler();
  }
  addHandler() {
    const openLogButton = this.element.querySelector(".js-copy-tuner-bar-open-log");
    openLogButton.addEventListener("click", (event) => {
      event.preventDefault();
      this.toggleLogMenu();
    });
    this.searchBoxElement.addEventListener("input", lodash_debounce(this.onKeyup.bind(this), 250));
  }
  show() {
    this.element.classList.remove(HIDDEN_CLASS);
    this.searchBoxElement.focus();
  }
  hide() {
    this.element.classList.add(HIDDEN_CLASS);
  }
  showLogMenu() {
    this.logMenuElement.classList.remove(HIDDEN_CLASS);
  }
  toggleLogMenu() {
    this.logMenuElement.classList.toggle(HIDDEN_CLASS);
  }
  makeLogMenu() {
    const div = document.createElement("div");
    div.setAttribute("id", "copy-tuner-bar-log-menu");
    div.classList.add(HIDDEN_CLASS);
    const table = document.createElement("table");
    const tbody = document.createElement("tbody");
    tbody.classList.remove("is-not-initialized");
    Object.keys(this.data).sort().forEach((key) => {
      const value = this.data[key];
      if (value === "") {
        return;
      }
      const td1 = document.createElement("td");
      td1.textContent = key;
      const td2 = document.createElement("td");
      td2.textContent = value;
      const tr = document.createElement("tr");
      tr.classList.add("copy-tuner-bar-log-menu__row");
      tr.dataset.key = key;
      tr.addEventListener("click", ({ currentTarget }) => {
        this.callback(currentTarget.dataset.key);
      });
      tr.appendChild(td1);
      tr.appendChild(td2);
      tbody.appendChild(tr);
    });
    table.appendChild(tbody);
    div.appendChild(table);
    return div;
  }
  onKeyup({ target }) {
    const keyword = target.value.trim();
    this.showLogMenu();
    const rows = Array.from(this.logMenuElement.getElementsByTagName("tr"));
    rows.forEach((row) => {
      const isShow = keyword === "" || Array.from(row.getElementsByTagName("td")).some((td) => td.textContent.includes(keyword));
      row.classList.toggle(HIDDEN_CLASS, !isShow);
    });
  }
}
const findBlurbs = () => {
  const filterNone = () => NodeFilter.FILTER_ACCEPT;
  const iterator = document.createNodeIterator(document.body, NodeFilter.SHOW_COMMENT, filterNone, false);
  const comments = [];
  let curNode;
  while (curNode = iterator.nextNode()) {
    comments.push(curNode);
  }
  return comments.filter((comment) => comment.nodeValue.startsWith("COPYRAY")).map((comment) => {
    const [, key] = comment.nodeValue.match(/^COPYRAY (\S*)$/);
    const element = comment.parentNode;
    return { key, element };
  });
};
class Copyray {
  constructor(baseUrl, data) {
    this.baseUrl = baseUrl;
    this.data = data;
    this.isShowing = false;
    this.specimens = [];
    this.overlay = this.makeOverlay();
    this.toggleButton = this.makeToggleButton();
    this.boundOpen = this.open.bind(this);
    this.copyTunerBar = new CopytunerBar(document.getElementById("copy-tuner-bar"), this.data, this.boundOpen);
  }
  show() {
    this.reset();
    document.body.appendChild(this.overlay);
    this.makeSpecimens();
    this.specimens.forEach((specimen) => {
      specimen.show();
    });
    this.copyTunerBar.show();
    this.isShowing = true;
  }
  hide() {
    this.overlay.remove();
    this.reset();
    this.copyTunerBar.hide();
    this.isShowing = false;
  }
  toggle() {
    if (this.isShowing) {
      this.hide();
    } else {
      this.show();
    }
  }
  open(key) {
    window.open(`${this.baseUrl}/blurbs/${key}/edit`);
  }
  makeSpecimens() {
    findBlurbs().forEach(({ element, key }) => {
      this.specimens.push(new Specimen(element, key, this.boundOpen));
    });
  }
  makeToggleButton() {
    const element = document.createElement("a");
    element.addEventListener("click", () => {
      this.show();
    });
    element.classList.add("copyray-toggle-button");
    element.classList.add("hidden-on-mobile");
    element.textContent = "Open CopyTuner";
    document.body.appendChild(element);
    return element;
  }
  makeOverlay() {
    const div = document.createElement("div");
    div.setAttribute("id", "copyray-overlay");
    div.addEventListener("click", () => this.hide());
    return div;
  }
  reset() {
    this.specimens.forEach((specimen) => {
      specimen.remove();
    });
  }
}
var copyray = "";
const start = () => {
  const dataElement = document.querySelector("#copy-tuner-data");
  if (!dataElement) {
    console.error("Not found #copy-tuner-data");
    return;
  }
  const copyTunerUrl = dataElement.dataset.copyTunerUrl;
  const data = JSON.parse(document.querySelector("#copy-tuner-data").dataset.copyTunerTranslationLog);
  const copyray2 = new Copyray(copyTunerUrl, data);
  document.addEventListener("keydown", (event) => {
    if (copyray2.isShowing && event.keyCode === keycodeJs.KEY_ESCAPE) {
      copyray2.hide();
      return;
    }
    if ((isMac && event.metaKey || !isMac && event.ctrlKey) && event.shiftKey && event.keyCode === keycodeJs.KEY_K) {
      copyray2.toggle();
    }
  });
  if (console) {
    console.log(`Ready to Copyray. Press ${isMac ? "cmd+shift+k" : "ctrl+shift+k"} to scan your UI.`);
  }
};
if (document.readyState === "complete" || document.readyState !== "loading") {
  start();
} else {
  document.addEventListener("DOMContentLoaded", start);
}
