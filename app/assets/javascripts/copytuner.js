var y = typeof globalThis < "u" ? globalThis : typeof window < "u" ? window : typeof global < "u" ? global : typeof self < "u" ? self : {}, $ = "Expected a function", C = 0 / 0, _ = "[object Symbol]", H = /^\s+|\s+$/g, q = /^[-+]0x[0-9a-f]+$/i, D = /^0b[01]+$/i, N = /^0o[0-7]+$/i, R = parseInt, W = typeof y == "object" && y && y.Object === Object && y, K = typeof self == "object" && self && self.Object === Object && self, U = W || K || Function("return this")(), F = Object.prototype, P = F.toString, X = Math.max, z = Math.min, v = function() {
  return U.Date.now();
};
function G(t, e, n) {
  var o, r, d, a, i, c, u = 0, E = !1, p = !1, b = !0;
  if (typeof t != "function")
    throw new TypeError($);
  e = O(e) || 0, x(n) && (E = !!n.leading, p = "maxWait" in n, d = p ? X(O(n.maxWait) || 0, e) : d, b = "trailing" in n ? !!n.trailing : b);
  function g(s) {
    var l = o, f = r;
    return o = r = void 0, u = s, a = t.apply(f, l), a;
  }
  function B(s) {
    return u = s, i = setTimeout(m, e), E ? g(s) : a;
  }
  function M(s) {
    var l = s - c, f = s - u, T = e - l;
    return p ? z(T, d - f) : T;
  }
  function w(s) {
    var l = s - c, f = s - u;
    return c === void 0 || l >= e || l < 0 || p && f >= d;
  }
  function m() {
    var s = v();
    if (w(s))
      return S(s);
    i = setTimeout(m, M(s));
  }
  function S(s) {
    return i = void 0, b && o ? g(s) : (o = r = void 0, a);
  }
  function I() {
    i !== void 0 && clearTimeout(i), u = 0, o = c = r = i = void 0;
  }
  function A() {
    return i === void 0 ? a : S(v());
  }
  function k() {
    var s = v(), l = w(s);
    if (o = arguments, r = this, c = s, l) {
      if (i === void 0)
        return B(c);
      if (p)
        return i = setTimeout(m, e), g(c);
    }
    return i === void 0 && (i = setTimeout(m, e)), a;
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
  return typeof t == "symbol" || V(t) && P.call(t) == _;
}
function O(t) {
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
  t = t.replace(H, "");
  var n = D.test(t);
  return n || N.test(t) ? R(t.slice(2), n ? 2 : 8) : q.test(t) ? C : +t;
}
var Z = G;
const h = "copy-tuner-hidden";
class J {
  // @ts-expect-error TS7006
  constructor(e, n, o) {
    this.element = e, this.data = n, this.callback = o, this.searchBoxElement = e.querySelector(".js-copy-tuner-bar-search"), this.logMenuElement = this.makeLogMenu(), this.element.append(this.logMenuElement), this.addHandler();
  }
  addHandler() {
    this.element.querySelector(".js-copy-tuner-bar-open-log").addEventListener("click", (n) => {
      n.preventDefault(), this.toggleLogMenu();
    }), this.searchBoxElement.addEventListener("input", Z(this.onKeyup.bind(this), 250));
  }
  show() {
    this.element.classList.remove(h), this.searchBoxElement.focus();
  }
  hide() {
    this.element.classList.add(h);
  }
  showLogMenu() {
    this.logMenuElement.classList.remove(h);
  }
  toggleLogMenu() {
    this.logMenuElement.classList.toggle(h);
  }
  makeLogMenu() {
    const e = document.createElement("div");
    e.setAttribute("id", "copy-tuner-bar-log-menu"), e.classList.add(h);
    const n = document.createElement("table"), o = document.createElement("tbody");
    o.classList.remove("is-not-initialized");
    for (const r of Object.keys(this.data).sort()) {
      const d = this.data[r];
      if (d === "")
        continue;
      const a = document.createElement("td");
      a.textContent = r;
      const i = document.createElement("td");
      i.textContent = d;
      const c = document.createElement("tr");
      c.classList.add("copy-tuner-bar-log-menu__row"), c.dataset.key = r, c.addEventListener("click", ({ currentTarget: u }) => {
        this.callback(u.dataset.key);
      }), c.append(a), c.append(i), o.append(c);
    }
    return n.append(o), e.append(n), e;
  }
  // @ts-expect-error TS7031
  onKeyup({ target: e }) {
    const n = e.value.trim();
    this.showLogMenu();
    const o = [...this.logMenuElement.querySelectorAll("tr")];
    for (const r of o) {
      const d = n === "" || [...r.querySelectorAll("td")].some((a) => a.textContent.includes(n));
      r.classList.toggle(h, !d);
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
    this.element = e, this.key = n, this.callback = o;
  }
  show() {
    this.box = this.makeBox(), this.box !== null && (this.box.addEventListener("click", () => {
      this.callback(this.key);
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
    for (const a of Object.keys(n)) {
      const i = n[a];
      e.style[a] = `${i}px`;
    }
    e.style.zIndex = ne;
    const { position: o, top: r, left: d } = getComputedStyle(this.element);
    return o === "fixed" && (this.box.style.position = "fixed", this.box.style.top = `${r}px`, this.box.style.left = `${d}px`), e.append(this.makeLabel()), e;
  }
  makeLabel() {
    const e = document.createElement("div");
    return e.classList.add("copyray-specimen-handle"), e.classList.add("Specimen"), e.textContent = this.key, e;
  }
}
const se = () => Array.from(document.querySelectorAll("[data-copyray-key]")).map((t) => ({
  key: t.getAttribute("data-copyray-key"),
  element: t
}));
class ie {
  // @ts-expect-error TS7006
  constructor(e, n) {
    this.baseUrl = e, this.data = n, this.isShowing = !1, this.specimens = [], this.overlay = this.makeOverlay(), this.toggleButton = this.makeToggleButton(), this.boundOpen = this.open.bind(this), this.copyTunerBar = new J(document.querySelector("#copy-tuner-bar"), this.data, this.boundOpen);
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
    for (const { element: e, key: n } of se())
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
}, j = () => {
  const { url: t, data: e } = window.CopyTuner;
  re(t);
  const n = new ie(t, e);
  window.CopyTuner.toggle = () => n.toggle(), document.addEventListener("keydown", (o) => {
    if (n.isShowing && ["Escape", "Esc"].includes(o.key)) {
      n.hide();
      return;
    }
    (L && o.metaKey || !L && o.ctrlKey) && o.shiftKey && o.key.toLowerCase() === "k" && n.toggle();
  }), console && console.log(`Ready to Copyray. Press ${L ? "cmd+shift+k" : "ctrl+shift+k"} to scan your UI.`);
};
document.readyState === "complete" || document.readyState !== "loading" ? j() : document.addEventListener("DOMContentLoaded", () => j());
