var y = typeof globalThis < "u" ? globalThis : typeof window < "u" ? window : typeof global < "u" ? global : typeof self < "u" ? self : {}, A = "Expected a function", C = 0 / 0, _ = "[object Symbol]", $ = /^\s+|\s+$/g, R = /^[-+]0x[0-9a-f]+$/i, H = /^0b[01]+$/i, W = /^0o[0-7]+$/i, F = parseInt, D = typeof y == "object" && y && y.Object === Object && y, P = typeof self == "object" && self && self.Object === Object && self, q = D || P || Function("return this")(), K = Object.prototype, U = K.toString, Y = Math.max, V = Math.min, v = function() {
  return q.Date.now();
};
function X(t, e, n) {
  var o, s, d, r, a, c, u = 0, x = !1, f = !1, b = !0;
  if (typeof t != "function")
    throw new TypeError(A);
  e = O(e) || 0, E(n) && (x = !!n.leading, f = "maxWait" in n, d = f ? Y(O(n.maxWait) || 0, e) : d, b = "trailing" in n ? !!n.trailing : b);
  function g(i) {
    var l = o, p = s;
    return o = s = void 0, u = i, r = t.apply(p, l), r;
  }
  function B(i) {
    return u = i, a = setTimeout(m, e), x ? g(i) : r;
  }
  function M(i) {
    var l = i - c, p = i - u, T = e - l;
    return f ? V(T, d - p) : T;
  }
  function w(i) {
    var l = i - c, p = i - u;
    return c === void 0 || l >= e || l < 0 || f && p >= d;
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
  function N() {
    return a === void 0 ? r : S(v());
  }
  function k() {
    var i = v(), l = w(i);
    if (o = arguments, s = this, c = i, l) {
      if (a === void 0)
        return B(c);
      if (f)
        return a = setTimeout(m, e), g(c);
    }
    return a === void 0 && (a = setTimeout(m, e)), r;
  }
  return k.cancel = I, k.flush = N, k;
}
function E(t) {
  var e = typeof t;
  return !!t && (e == "object" || e == "function");
}
function z(t) {
  return !!t && typeof t == "object";
}
function G(t) {
  return typeof t == "symbol" || z(t) && U.call(t) == _;
}
function O(t) {
  if (typeof t == "number")
    return t;
  if (G(t))
    return C;
  if (E(t)) {
    var e = typeof t.valueOf == "function" ? t.valueOf() : t;
    t = E(e) ? e + "" : e;
  }
  if (typeof t != "string")
    return t === 0 ? t : +t;
  t = t.replace($, "");
  var n = H.test(t);
  return n || W.test(t) ? F(t.slice(2), n ? 2 : 8) : R.test(t) ? C : +t;
}
var Z = X;
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
    for (const s of Object.keys(this.data).sort()) {
      const d = this.data[s];
      if (d === "")
        continue;
      const r = document.createElement("td");
      r.textContent = s;
      const a = document.createElement("td");
      a.textContent = d;
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
      const d = n === "" || [...s.querySelectorAll("td")].some((r) => r.textContent.includes(n));
      s.classList.toggle(h, !d);
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
    for (const r of Object.keys(n)) {
      const a = n[r];
      e.style[r] = `${a}px`;
    }
    e.style.zIndex = ne;
    const { position: o, top: s, left: d } = getComputedStyle(this.element);
    return o === "fixed" && (this.box.style.position = "fixed", this.box.style.top = `${s}px`, this.box.style.left = `${d}px`), e.append(this.makeLabel()), e;
  }
  makeLabel() {
    const e = document.createElement("div");
    return e.classList.add("copyray-specimen-handle"), e.classList.add("Specimen"), e.textContent = this.key, e;
  }
}
const se = () => {
  const t = () => NodeFilter.FILTER_ACCEPT, e = document.createNodeIterator(document.body, NodeFilter.SHOW_COMMENT, t, !1), n = [];
  let o;
  for (; o = e.nextNode(); )
    n.push(o);
  return n.filter((s) => s.nodeValue.startsWith("COPYRAY")).map((s) => {
    const [, d] = s.nodeValue.match(/^COPYRAY (\S*)$/), r = s.parentNode;
    return { key: d, element: r };
  });
};
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
