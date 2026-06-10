var y = typeof globalThis < "u" ? globalThis : typeof window < "u" ? window : typeof global < "u" ? global : typeof self < "u" ? self : {}, A = "Expected a function", C = 0 / 0, _ = "[object Symbol]", F = /^\s+|\s+$/g, $ = /^[-+]0x[0-9a-f]+$/i, R = /^0b[01]+$/i, H = /^0o[0-7]+$/i, W = parseInt, D = typeof y == "object" && y && y.Object === Object && y, P = typeof self == "object" && self && self.Object === Object && self, U = D || P || Function("return this")(), V = Object.prototype, q = V.toString, K = Math.max, Y = Math.min, E = function() {
  return U.Date.now();
};
function X(t, e, n) {
  var o, s, a, i, c, l, u = 0, x = !1, f = !1, b = !0;
  if (typeof t != "function")
    throw new TypeError(A);
  e = O(e) || 0, v(n) && (x = !!n.leading, f = "maxWait" in n, a = f ? K(O(n.maxWait) || 0, e) : a, b = "trailing" in n ? !!n.trailing : b);
  function g(r) {
    var d = o, m = s;
    return o = s = void 0, u = r, i = t.apply(m, d), i;
  }
  function I(r) {
    return u = r, c = setTimeout(p, e), x ? g(r) : i;
  }
  function N(r) {
    var d = r - l, m = r - u, S = e - d;
    return f ? Y(S, a - m) : S;
  }
  function w(r) {
    var d = r - l, m = r - u;
    return l === void 0 || d >= e || d < 0 || f && m >= a;
  }
  function p() {
    var r = E();
    if (w(r))
      return T(r);
    c = setTimeout(p, N(r));
  }
  function T(r) {
    return c = void 0, b && o ? g(r) : (o = s = void 0, i);
  }
  function j() {
    c !== void 0 && clearTimeout(c), u = 0, o = l = s = c = void 0;
  }
  function M() {
    return c === void 0 ? i : T(E());
  }
  function k() {
    var r = E(), d = w(r);
    if (o = arguments, s = this, l = r, d) {
      if (c === void 0)
        return I(l);
      if (f)
        return c = setTimeout(p, e), g(l);
    }
    return c === void 0 && (c = setTimeout(p, e)), i;
  }
  return k.cancel = j, k.flush = M, k;
}
function v(t) {
  var e = typeof t;
  return !!t && (e == "object" || e == "function");
}
function z(t) {
  return !!t && typeof t == "object";
}
function G(t) {
  return typeof t == "symbol" || z(t) && q.call(t) == _;
}
function O(t) {
  if (typeof t == "number")
    return t;
  if (G(t))
    return C;
  if (v(t)) {
    var e = typeof t.valueOf == "function" ? t.valueOf() : t;
    t = v(e) ? e + "" : e;
  }
  if (typeof t != "string")
    return t === 0 ? t : +t;
  t = t.replace(F, "");
  var n = R.test(t);
  return n || H.test(t) ? W(t.slice(2), n ? 2 : 8) : $.test(t) ? C : +t;
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
      const a = this.data[s];
      if (a === "")
        continue;
      const i = document.createElement("td");
      i.textContent = s;
      const c = document.createElement("td");
      c.textContent = a;
      const l = document.createElement("tr");
      l.classList.add("copy-tuner-bar-log-menu__row"), l.dataset.key = s, l.addEventListener("click", ({ currentTarget: u }) => {
        this.callback(u.dataset.key);
      }), l.append(i), l.append(c), o.append(l);
    }
    return n.append(o), e.append(n), e;
  }
  // @ts-expect-error TS7031
  onKeyup({ target: e }) {
    const n = e.value.trim();
    this.showLogMenu();
    const o = [...this.logMenuElement.querySelectorAll("tr")];
    for (const s of o) {
      const a = n === "" || [...s.querySelectorAll("td")].some((i) => i.textContent.includes(n));
      s.classList.toggle(h, !a);
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
    for (const i of Object.keys(n)) {
      const c = n[i];
      e.style[i] = `${c}px`;
    }
    e.style.zIndex = ne;
    const { position: o, top: s, left: a } = getComputedStyle(this.element);
    return o === "fixed" && (this.box.style.position = "fixed", this.box.style.top = `${s}px`, this.box.style.left = `${a}px`), e.append(this.makeLabel()), e;
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
    const [, a] = s.nodeValue.match(/^COPYRAY (\S*)$/), i = s.parentNode;
    return { key: a, element: i };
  });
}, ie = ["‌", "‍"], re = /[‌‍]+/g, ae = (t) => {
  const n = (Array.from(t).map((o) => ie.indexOf(o)).join("").match(/.{9}/g) ?? []).map((o) => parseInt(o.slice(0, 8), 2));
  return new TextDecoder().decode(new Uint8Array(n));
}, ce = () => {
  const t = () => NodeFilter.FILTER_ACCEPT, e = document.createNodeIterator(document.body, NodeFilter.SHOW_TEXT, t, !1), n = [];
  let o;
  for (; o = e.nextNode(); ) {
    const s = (o.nodeValue ?? "").match(re);
    if (s)
      for (const a of s) {
        if (a.length % 9 !== 0)
          continue;
        const i = ae(a);
        i && n.push({ key: i, element: o.parentNode });
      }
  }
  return n;
}, le = (t) => t === "subliminal" ? ce() : se();
class de {
  // @ts-expect-error TS7006
  constructor(e, n, o) {
    this.baseUrl = e, this.data = n, this.markerType = o, this.isShowing = !1, this.specimens = [], this.overlay = this.makeOverlay(), this.toggleButton = this.makeToggleButton(), this.boundOpen = this.open.bind(this), this.copyTunerBar = new J(document.querySelector("#copy-tuner-bar"), this.data, this.boundOpen);
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
    for (const { element: e, key: n } of le(this.markerType))
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
const ue = (t) => {
  const e = document.createElement("div");
  e.id = "copy-tuner-bar", e.classList.add("copy-tuner-hidden"), e.innerHTML = `
    <a class="copy-tuner-bar-button" target="_blank" href="${t}">CopyTuner</a>
    <a href="/copytuner" target="_blank" class="copy-tuner-bar-button">Sync</a>
    <a href="javascript:void(0)" class="copy-tuner-bar-open-log copy-tuner-bar-button js-copy-tuner-bar-open-log">Translations in this page</a>
    <input type="text" class="copy-tuner-bar__search js-copy-tuner-bar-search" placeholder="search">
  `, document.body.append(e);
}, B = () => {
  const { url: t, data: e, markerType: n } = window.CopyTuner;
  ue(t);
  const o = new de(t, e, n);
  window.CopyTuner.toggle = () => o.toggle(), document.addEventListener("keydown", (s) => {
    if (o.isShowing && ["Escape", "Esc"].includes(s.key)) {
      o.hide();
      return;
    }
    (L && s.metaKey || !L && s.ctrlKey) && s.shiftKey && s.key.toLowerCase() === "k" && o.toggle();
  }), console && console.log(`Ready to Copyray. Press ${L ? "cmd+shift+k" : "ctrl+shift+k"} to scan your UI.`);
};
document.readyState === "complete" || document.readyState !== "loading" ? B() : document.addEventListener("DOMContentLoaded", () => B());
