var y = typeof globalThis < "u" ? globalThis : typeof window < "u" ? window : typeof global < "u" ? global : typeof self < "u" ? self : {}, _ = "Expected a function", C = 0 / 0, $ = "[object Symbol]", N = /^\s+|\s+$/g, H = /^[-+]0x[0-9a-f]+$/i, q = /^0b[01]+$/i, D = /^0o[0-7]+$/i, R = parseInt, U = typeof y == "object" && y && y.Object === Object && y, W = typeof self == "object" && self && self.Object === Object && self, K = U || W || Function("return this")(), F = Object.prototype, P = F.toString, X = Math.max, z = Math.min, v = function() {
  return K.Date.now();
};
function G(t, e, n) {
  var o, s, l, r, a, c, u = 0, E = !1, h = !1, b = !0;
  if (typeof t != "function")
    throw new TypeError(_);
  e = B(e) || 0, x(n) && (E = !!n.leading, h = "maxWait" in n, l = h ? X(B(n.maxWait) || 0, e) : l, b = "trailing" in n ? !!n.trailing : b);
  function g(i) {
    var d = o, f = s;
    return o = s = void 0, u = i, r = t.apply(f, d), r;
  }
  function j(i) {
    return u = i, a = setTimeout(m, e), E ? g(i) : r;
  }
  function M(i) {
    var d = i - c, f = i - u, T = e - d;
    return h ? z(T, l - f) : T;
  }
  function w(i) {
    var d = i - c, f = i - u;
    return c === void 0 || d >= e || d < 0 || h && f >= l;
  }
  function m() {
    var i = v();
    if (w(i))
      return S(i);
    a = setTimeout(m, M(i));
  }
  function S(i) {
    return a = void 0, b && o ? g(i) : (o = s = void 0, r);
  }
  function I() {
    a !== void 0 && clearTimeout(a), u = 0, o = c = s = a = void 0;
  }
  function A() {
    return a === void 0 ? r : S(v());
  }
  function k() {
    var i = v(), d = w(i);
    if (o = arguments, s = this, c = i, d) {
      if (a === void 0)
        return j(c);
      if (h)
        return a = setTimeout(m, e), g(c);
    }
    return a === void 0 && (a = setTimeout(m, e)), r;
  }
  return k.cancel = I, k.flush = A, k;
}
function x(t) {
  var e = typeof t;
  return !!t && (e == "object" || e == "function");
}
function V(t) {
  return !!t && typeof t == "object";
}
function Y(t) {
  return typeof t == "symbol" || V(t) && P.call(t) == $;
}
function B(t) {
  if (typeof t == "number")
    return t;
  if (Y(t))
    return C;
  if (x(t)) {
    var e = typeof t.valueOf == "function" ? t.valueOf() : t;
    t = x(e) ? e + "" : e;
  }
  if (typeof t != "string")
    return t === 0 ? t : +t;
  t = t.replace(N, "");
  var n = q.test(t);
  return n || D.test(t) ? R(t.slice(2), n ? 2 : 8) : H.test(t) ? C : +t;
}
var Z = G;
const p = "copy-tuner-hidden";
class J {
  // @ts-expect-error TS7006
  constructor(e, n, o, s = !1) {
    this.element = e, this.data = n, this.callback = o, this.searchBoxElement = e.querySelector(".js-copy-tuner-bar-search"), this.logMenuElement = this.makeLogMenu(), this.element.append(this.logMenuElement), s && this.appendSkippedNotice(), this.addHandler();
  }
  appendSkippedNotice() {
    const e = document.createElement("span");
    e.classList.add("copy-tuner-bar__notice"), e.textContent = '⚠ This page is too large for the overlay. Use "Translations in this page" to edit.', this.element.append(e);
  }
  addHandler() {
    this.element.querySelector(".js-copy-tuner-bar-open-log").addEventListener("click", (n) => {
      n.preventDefault(), this.toggleLogMenu();
    }), this.searchBoxElement.addEventListener("input", Z(this.onKeyup.bind(this), 250));
  }
  show() {
    this.element.classList.remove(p), this.searchBoxElement.focus();
  }
  hide() {
    this.element.classList.add(p);
  }
  showLogMenu() {
    this.logMenuElement.classList.remove(p);
  }
  toggleLogMenu() {
    this.logMenuElement.classList.toggle(p);
  }
  makeLogMenu() {
    const e = document.createElement("div");
    e.setAttribute("id", "copy-tuner-bar-log-menu"), e.classList.add(p);
    const n = document.createElement("table"), o = document.createElement("tbody");
    o.classList.remove("is-not-initialized");
    for (const s of Object.keys(this.data).sort()) {
      const l = this.data[s];
      if (l === "")
        continue;
      const r = document.createElement("td");
      r.textContent = s;
      const a = document.createElement("td");
      a.textContent = l;
      const c = document.createElement("tr");
      c.classList.add("copy-tuner-bar-log-menu__row"), c.dataset.key = s, c.addEventListener("click", ({ currentTarget: u }) => {
        this.callback(u.dataset.key);
      }), c.append(r), c.append(a), o.append(c);
    }
    return n.append(o), e.append(n), e;
  }
  // @ts-expect-error TS7031
  onKeyup({ target: e }) {
    const n = e.value.trim();
    this.showLogMenu();
    const o = [...this.logMenuElement.querySelectorAll("tr")];
    for (const s of o) {
      const l = n === "" || [...s.querySelectorAll("td")].some((r) => r.textContent.includes(n));
      s.classList.toggle(p, !l);
    }
  }
}
const L = navigator.platform.toUpperCase().includes("MAC"), Q = (t) => !!(t.offsetWidth || t.offsetHeight || t.getClientRects().length > 0), ee = (t) => {
  const e = t.getBoundingClientRect();
  return {
    top: e.top + (window.pageYOffset - document.documentElement.clientTop),
    left: e.left + (window.pageXOffset - document.documentElement.clientLeft)
  };
}, te = (t) => {
  if (!Q(t))
    return null;
  const e = ee(t);
  return e.right = e.left + t.offsetWidth, e.bottom = e.top + t.offsetHeight, {
    left: e.left,
    top: e.top,
    // @ts-expect-error TS2339
    width: e.right - e.left,
    // @ts-expect-error TS2339
    height: e.bottom - e.top
  };
}, ne = 2e9;
class oe {
  // @ts-expect-error TS7006
  constructor(e, n, o) {
    this.element = e, this.keys = n, this.callback = o;
  }
  show() {
    this.box = this.makeBox(), this.box !== null && (this.box.addEventListener("click", () => {
      this.callback(this.keys[0]);
    }), document.body.append(this.box));
  }
  remove() {
    this.box && (this.box.remove(), this.box = null);
  }
  makeBox() {
    const e = document.createElement("div");
    e.classList.add("copyray-specimen"), e.classList.add("Specimen");
    const n = te(this.element);
    if (n === null)
      return null;
    for (const r of Object.keys(n)) {
      const a = n[r];
      e.style[r] = `${a}px`;
    }
    e.style.zIndex = ne;
    const { position: o, top: s, left: l } = getComputedStyle(this.element);
    o === "fixed" && (this.box.style.position = "fixed", this.box.style.top = `${s}px`, this.box.style.left = `${l}px`);
    for (const r of this.keys)
      e.append(this.makeLabel(r));
    return e;
  }
  // @ts-expect-error TS7006
  makeLabel(e) {
    const n = document.createElement("div");
    return n.classList.add("copyray-specimen-handle"), n.classList.add("Specimen"), n.textContent = e, n.addEventListener("click", (o) => {
      o.stopPropagation(), this.callback(e);
    }), n;
  }
}
const se = () => Array.from(document.querySelectorAll("[data-copyray-key]")).map((t) => ({
  // 1 要素に複数キーがカンマ区切りで入りうる（同一テキストノードに複数訳文が連結された場合）
  keys: (t.getAttribute("data-copyray-key") ?? "").split(",").filter(Boolean),
  element: t
}));
class ie {
  // @ts-expect-error TS7006
  constructor(e, n, o = !1) {
    this.baseUrl = e, this.data = n, this.isShowing = !1, this.specimens = [], this.overlay = this.makeOverlay(), this.toggleButton = this.makeToggleButton(), this.boundOpen = this.open.bind(this), this.copyTunerBar = new J(document.querySelector("#copy-tuner-bar"), this.data, this.boundOpen, o);
  }
  show() {
    this.reset(), document.body.append(this.overlay), this.makeSpecimens();
    for (const e of this.specimens)
      e.show();
    this.copyTunerBar.show(), this.isShowing = !0;
  }
  hide() {
    this.overlay.remove(), this.reset(), this.copyTunerBar.hide(), this.isShowing = !1;
  }
  toggle() {
    this.isShowing ? this.hide() : this.show();
  }
  // @ts-expect-error TS7006
  open(e) {
    window.open(`${this.baseUrl}/blurbs/${e}/edit`);
  }
  makeSpecimens() {
    for (const { element: e, keys: n } of se())
      this.specimens.push(new oe(e, n, this.boundOpen));
  }
  makeToggleButton() {
    const e = document.createElement("a");
    return e.addEventListener("click", () => {
      this.show();
    }), e.classList.add("copyray-toggle-button"), e.classList.add("hidden-on-mobile"), e.textContent = "Open CopyTuner", document.body.append(e), e;
  }
  makeOverlay() {
    const e = document.createElement("div");
    return e.setAttribute("id", "copyray-overlay"), e.addEventListener("click", () => this.hide()), e;
  }
  reset() {
    for (const e of this.specimens)
      e.remove();
  }
}
const re = (t) => {
  const e = document.createElement("div");
  e.id = "copy-tuner-bar", e.classList.add("copy-tuner-hidden"), e.innerHTML = `
    <a class="copy-tuner-bar-button" target="_blank" href="${t}">CopyTuner</a>
    <a href="/copytuner" target="_blank" class="copy-tuner-bar-button">Sync</a>
    <a href="javascript:void(0)" class="copy-tuner-bar-open-log copy-tuner-bar-button js-copy-tuner-bar-open-log">Translations in this page</a>
    <input type="text" class="copy-tuner-bar__search js-copy-tuner-bar-search" placeholder="search">
  `, document.body.append(e);
}, O = () => {
  const { url: t, data: e, keysSkipped: n } = window.CopyTuner;
  re(t);
  const o = new ie(t, e, !!n);
  window.CopyTuner.toggle = () => o.toggle(), document.addEventListener("keydown", (s) => {
    if (o.isShowing && ["Escape", "Esc"].includes(s.key)) {
      o.hide();
      return;
    }
    (L && s.metaKey || !L && s.ctrlKey) && s.shiftKey && s.key.toLowerCase() === "k" && o.toggle();
  }), console && console.log(`Ready to Copyray. Press ${L ? "cmd+shift+k" : "ctrl+shift+k"} to scan your UI.`);
};
document.readyState === "complete" || document.readyState !== "loading" ? O() : document.addEventListener("DOMContentLoaded", () => O());
