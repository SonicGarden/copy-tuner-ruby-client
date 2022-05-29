var __defProp = Object.defineProperty;
var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
var __publicField = (obj, key, value) => {
  __defNormalProp(obj, typeof key !== "symbol" ? key + "" : key, value);
  return value;
};
function isObject(value) {
  var type = typeof value;
  return value != null && type === "object";
}
function debounce(func, wait, options) {
  var lastArgs;
  var lastThis;
  var result;
  var lastCallTime;
  var timerId;
  var lastInvokeTime = 0;
  var useRAF = wait === void 0 && typeof window !== "undefined" && typeof window.requestAnimationFrame === "function";
  if (typeof func !== "function") {
    throw new TypeError("Expected a function");
  }
  var waitValue = Number(wait) || 0;
  var leading = false;
  var trailing = true;
  var maxWait = null;
  if (isObject(options)) {
    leading = !!options.leading;
    maxWait = "maxWait" in options ? Math.max(Number(options.maxWait) || 0, waitValue) : maxWait;
    trailing = "trailing" in options ? !!options.trailing : trailing;
  }
  function invokeFunc(time) {
    var args = lastArgs;
    var thisArg = lastThis;
    lastArgs = lastThis = void 0;
    lastInvokeTime = time;
    result = func.apply(thisArg, args);
    return result;
  }
  function startTimer(pendingFunc, wait2) {
    if (useRAF && typeof timerId === "number") {
      window.cancelAnimationFrame(timerId);
      return window.requestAnimationFrame(pendingFunc);
    }
    return setTimeout(pendingFunc, wait2);
  }
  function cancelTimer(id) {
    if (useRAF && typeof id === "number") {
      window.cancelAnimationFrame(id);
    }
    clearTimeout(id);
  }
  function leadingEdge(time) {
    lastInvokeTime = time;
    timerId = startTimer(timerExpired, waitValue);
    return leading ? invokeFunc(time) : result;
  }
  function remainingWait(time) {
    if (lastCallTime === void 0)
      return 0;
    var timeSinceLastCall = time - lastCallTime;
    var timeSinceLastInvoke = time - lastInvokeTime;
    var timeWaiting = waitValue - timeSinceLastCall;
    return maxWait !== null ? Math.min(timeWaiting, maxWait - timeSinceLastInvoke) : timeWaiting;
  }
  function shouldInvoke(time) {
    if (lastCallTime === void 0)
      return true;
    var timeSinceLastCall = time - lastCallTime;
    var timeSinceLastInvoke = time - lastInvokeTime;
    return timeSinceLastCall >= waitValue || timeSinceLastCall < 0 || maxWait !== null && timeSinceLastInvoke >= maxWait;
  }
  function timerExpired() {
    var time = Date.now();
    if (shouldInvoke(time)) {
      return trailingEdge(time);
    }
    timerId = startTimer(timerExpired, remainingWait(time));
    return;
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
      cancelTimer(timerId);
    }
    lastInvokeTime = 0;
    lastArgs = lastCallTime = lastThis = timerId = void 0;
  }
  function flush() {
    return timerId === void 0 ? result : trailingEdge(Date.now());
  }
  function pending() {
    return timerId !== void 0;
  }
  function debounced() {
    var args = [];
    for (var _i = 0; _i < arguments.length; _i++) {
      args[_i] = arguments[_i];
    }
    var time = Date.now();
    var isInvoking = shouldInvoke(time);
    lastArgs = args;
    lastThis = this;
    lastCallTime = time;
    if (isInvoking) {
      if (timerId === void 0) {
        return leadingEdge(lastCallTime);
      }
      if (maxWait !== null) {
        timerId = startTimer(timerExpired, waitValue);
        return invokeFunc(lastCallTime);
      }
    }
    if (timerId === void 0) {
      timerId = startTimer(timerExpired, waitValue);
    }
    return result;
  }
  debounced.cancel = cancel;
  debounced.flush = flush;
  debounced.pending = pending;
  return debounced;
}
const HIDDEN_CLASS = "copy-tuner-hidden";
class CopytunerBar {
  constructor(element, data, callback) {
    __publicField(this, "callback");
    __publicField(this, "element");
    __publicField(this, "data");
    __publicField(this, "searchBoxElement");
    __publicField(this, "logMenuElement");
    this.element = element;
    this.data = data;
    this.callback = callback;
    this.searchBoxElement = element.querySelector(".js-copy-tuner-bar-search");
    this.logMenuElement = this.makeLogMenu();
    this.element.append(this.logMenuElement);
    this.addHandler();
  }
  addHandler() {
    const openLogButton = this.element.querySelector(".js-copy-tuner-bar-open-log");
    openLogButton.addEventListener("click", (event) => {
      event.preventDefault();
      this.toggleLogMenu();
    });
    this.searchBoxElement.addEventListener("input", debounce(this.onInput.bind(this), 250));
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
    for (const key of Object.keys(this.data).sort()) {
      const value = this.data[key];
      if (value === "") {
        continue;
      }
      const td1 = document.createElement("td");
      td1.textContent = key;
      const td2 = document.createElement("td");
      td2.textContent = value;
      const tr = document.createElement("tr");
      tr.classList.add("copy-tuner-bar-log-menu__row");
      tr.dataset.key = key;
      tr.addEventListener("click", (event) => {
        this.callback(event.currentTarget.dataset.key);
      });
      tr.append(td1);
      tr.append(td2);
      tbody.append(tr);
    }
    table.append(tbody);
    div.append(table);
    return div;
  }
  onInput(event) {
    const keyword = event.target.value.trim();
    this.showLogMenu();
    const rows = [...this.logMenuElement.querySelectorAll("tr")];
    for (const row of rows) {
      const isShow = keyword === "" || [...row.querySelectorAll("td")].some((td) => {
        var _a;
        return (_a = td.textContent) == null ? void 0 : _a.includes(keyword);
      });
      row.classList.toggle(HIDDEN_CLASS, !isShow);
    }
  }
}
const isMac = navigator.userAgent.toUpperCase().includes("MAC");
const isVisible = (element) => !!(element.offsetWidth || element.offsetHeight || element.getClientRects().length > 0);
const getOffset = (element) => {
  const box = element.getBoundingClientRect();
  return {
    top: box.top + (window.pageYOffset - document.documentElement.clientTop),
    left: box.left + (window.pageXOffset - document.documentElement.clientLeft)
  };
};
const computeBoundingBox = (element) => {
  if (!isVisible(element)) {
    return;
  }
  const boxFrame = getOffset(element);
  const right = boxFrame.left + element.offsetWidth;
  const bottom = boxFrame.top + element.offsetHeight;
  return {
    left: boxFrame.left,
    top: boxFrame.top,
    width: right - boxFrame.left,
    height: bottom - boxFrame.top
  };
};
const ZINDEX = 2e9;
class Specimen {
  constructor(element, key, onOpen) {
    __publicField(this, "element");
    __publicField(this, "key");
    __publicField(this, "onOpen");
    __publicField(this, "box");
    this.element = element;
    this.key = key;
    this.onOpen = onOpen;
  }
  show() {
    this.box = this.makeBox();
    if (!this.box)
      return;
    this.box.addEventListener("click", () => {
      this.onOpen(this.key);
    });
    document.body.append(this.box);
  }
  remove() {
    if (!this.box) {
      return;
    }
    this.box.remove();
    this.box = void 0;
  }
  makeBox() {
    const box = document.createElement("div");
    box.classList.add("copyray-specimen");
    box.classList.add("Specimen");
    const bounds = computeBoundingBox(this.element);
    if (!bounds)
      return;
    for (const key of ["left", "top", "width", "height"]) {
      const value = bounds[key];
      box.style[key] = `${value}px`;
    }
    box.style.zIndex = ZINDEX.toString();
    const { position, top, left } = getComputedStyle(this.element);
    if (this.box && position === "fixed") {
      this.box.style.position = "fixed";
      this.box.style.top = `${top}px`;
      this.box.style.left = `${left}px`;
    }
    box.append(this.makeLabel());
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
const COPYRAY_PREFIX = "COPYRAY";
const findCopyrayComments = () => {
  const filterNone = (node) => {
    var _a;
    return ((_a = node.nodeValue) == null ? void 0 : _a.startsWith(COPYRAY_PREFIX)) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
  };
  const iterator = document.createNodeIterator(document.body, NodeFilter.SHOW_COMMENT, filterNone);
  const comments = [];
  let curNode;
  while (curNode = iterator.nextNode()) {
    comments.push(curNode);
  }
  return comments;
};
const findBlurbs = () => {
  return findCopyrayComments().map((comment) => {
    const key = comment.nodeValue.replace(COPYRAY_PREFIX, "").trim();
    const element = comment.parentNode;
    return { key, element };
  });
};
class Copyray {
  constructor(baseUrl, data) {
    __publicField(this, "isShowing");
    __publicField(this, "baseUrl");
    __publicField(this, "data");
    __publicField(this, "copyTunerBar");
    __publicField(this, "boundOpen");
    __publicField(this, "overlay");
    __publicField(this, "specimens");
    this.baseUrl = baseUrl;
    this.data = data;
    this.isShowing = false;
    this.specimens = [];
    this.overlay = this.makeOverlay();
    this.boundOpen = this.open.bind(this);
    this.copyTunerBar = new CopytunerBar(document.querySelector("#copy-tuner-bar"), this.data, this.boundOpen);
    this.appendToggleButton();
  }
  show() {
    this.reset();
    document.body.append(this.overlay);
    this.makeSpecimens();
    for (const specimen of this.specimens) {
      specimen.show();
    }
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
    for (const { element, key } of findBlurbs()) {
      this.specimens.push(new Specimen(element, key, this.boundOpen));
    }
  }
  appendToggleButton() {
    const element = document.createElement("a");
    element.addEventListener("click", () => {
      this.show();
    });
    element.classList.add("copyray-toggle-button");
    element.classList.add("hidden-on-mobile");
    element.textContent = "Open CopyTuner";
    document.body.append(element);
    return element;
  }
  makeOverlay() {
    const div = document.createElement("div");
    div.setAttribute("id", "copyray-overlay");
    div.addEventListener("click", () => this.hide());
    return div;
  }
  reset() {
    for (const specimen of this.specimens) {
      specimen.remove();
    }
  }
}
var copyray = "";
const appendCopyTunerBar = (url) => {
  const bar = document.createElement("div");
  bar.id = "copy-tuner-bar";
  bar.classList.add("copy-tuner-hidden");
  bar.innerHTML = `
    <a class="copy-tuner-bar-button" target="_blank" href="${url}">CopyTuner</a>
    <a href="/copytuner" target="_blank" class="copy-tuner-bar-button">Sync</a>
    <a href="javascript:void(0)" class="copy-tuner-bar-open-log copy-tuner-bar-button js-copy-tuner-bar-open-log">Translations in this page</a>
    <input type="text" class="copy-tuner-bar__search js-copy-tuner-bar-search" placeholder="search">
  `;
  document.body.append(bar);
};
const start = () => {
  const { url, data } = window.CopyTuner;
  appendCopyTunerBar(url);
  const copyray2 = new Copyray(url, data);
  document.addEventListener("keydown", (event) => {
    if (copyray2.isShowing && ["Escape", "Esc"].includes(event.key)) {
      copyray2.hide();
      return;
    }
    if ((isMac && event.metaKey || !isMac && event.ctrlKey) && event.shiftKey && event.key === "k") {
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
  document.addEventListener("DOMContentLoaded", () => start());
}
