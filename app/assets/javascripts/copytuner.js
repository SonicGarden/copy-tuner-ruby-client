//#region src/styles.ts
var e = () => Array.from(document.querySelectorAll("[data-copyray-key]")).map((e) => ({
	keys: (e.getAttribute("data-copyray-key") ?? "").split(",").filter(Boolean),
	element: e
})), t = class extends HTMLElement {
	#e = () => {};
	#t = () => {};
	#n;
	#r;
	#i = /* @__PURE__ */ new Map();
	#a = null;
	constructor() {
		super();
		let e = this.attachShadow({ mode: "open" }), t = document.createElement("style");
		t.textContent = "\n:host {\n  position: absolute;\n  width: 0;\n  height: 0;\n}\n\n.backdrop {\n  position: fixed;\n  inset: 0;\n  background-image: radial-gradient(\n    ellipse farthest-corner at center,\n    rgba(0, 0, 0, 0.4) 10%,\n    rgba(0, 0, 0, 0.8) 100%\n  );\n  z-index: 9000;\n}\n\n.specimen {\n  position: fixed;\n  background: rgba(255, 50, 50, 0.1);\n  outline: 1px solid rgba(255, 50, 50, 0.8);\n  outline-offset: -1px;\n  color: #666;\n  font-family: 'Helvetica Neue', sans-serif;\n  font-size: 13px;\n  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.7);\n  z-index: 2000000000;\n}\n\n.specimen:hover {\n  cursor: pointer;\n  background: rgba(255, 50, 50, 0.4);\n}\n\n.specimen[hidden] {\n  display: none;\n}\n\n.specimen-handle {\n  float: left;\n  margin: 0 2px 2px 0;\n  background: rgba(255, 50, 50, 0.8);\n  padding: 0 3px;\n  color: #fff;\n  font-size: 10px;\n  cursor: pointer;\n}\n", e.append(t), this.#n = document.createElement("div"), this.#n.classList.add("backdrop"), this.#n.addEventListener("click", () => this.#t()), this.#r = document.createElement("div"), e.append(this.#n, this.#r);
	}
	set onOpen(e) {
		this.#e = e;
	}
	set onClose(e) {
		this.#t = e;
	}
	show() {
		this.hide();
		for (let { element: t, keys: n } of e()) this.#i.set(t, this.makeBox(n));
		this.#s(), this.#r.append(...this.#i.values()), document.addEventListener("scroll", this.#o, {
			capture: !0,
			passive: !0
		}), window.addEventListener("resize", this.#o, { passive: !0 });
	}
	hide() {
		document.removeEventListener("scroll", this.#o, { capture: !0 }), window.removeEventListener("resize", this.#o), this.#a !== null && (cancelAnimationFrame(this.#a), this.#a = null), this.#i.clear(), this.#r.replaceChildren();
	}
	#o = () => {
		this.#a === null && (this.#a = requestAnimationFrame(() => {
			this.#a = null, this.#s();
		}));
	};
	#s() {
		let e = Array.from(this.#i, ([e, t]) => [t, e.getBoundingClientRect()]);
		for (let [t, n] of e) t.hidden = n.width === 0 && n.height === 0, !t.hidden && (t.style.left = `${n.left}px`, t.style.top = `${n.top}px`, t.style.width = `${n.width}px`, t.style.height = `${n.height}px`);
	}
	makeBox(e) {
		let t = document.createElement("div");
		t.classList.add("specimen"), t.addEventListener("click", () => this.#e(e[0]));
		for (let n of e) t.append(this.makeLabel(n));
		return t;
	}
	makeLabel(e) {
		let t = document.createElement("div");
		return t.classList.add("specimen-handle"), t.textContent = e, t.addEventListener("click", (t) => {
			t.stopPropagation(), this.#e(e);
		}), t;
	}
}, n = navigator.platform.toUpperCase().includes("MAC"), r = (e, t) => {
	let n;
	return (...r) => {
		clearTimeout(n), n = setTimeout(() => e(...r), t);
	};
}, i = class extends HTMLElement {
	#e = () => {};
	#t;
	#n;
	constructor() {
		super(), this.attachShadow({ mode: "open" });
	}
	init({ url: e, data: t, keysSkipped: n, onOpen: i }) {
		this.#e = i;
		let a = this.shadowRoot, o = document.createElement("style");
		o.textContent = "\n:host {\n  position: fixed;\n  left: 0;\n  right: 0;\n  bottom: 0;\n  height: 40px;\n  padding: 0 8px;\n  background: #222;\n  font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;\n  font-weight: 200;\n  color: #fff;\n  z-index: 2147483647;\n  box-shadow: 0 -1px 0 rgba(255, 255, 255, 0.1), inset 0 2px 6px rgba(0, 0, 0, 0.8);\n  background-image: linear-gradient(rgba(0, 0, 0, 0), rgba(0, 0, 0, 0.3));\n  box-sizing: border-box;\n}\n\n.log-menu {\n  position: fixed;\n  left: 0;\n  right: 0;\n  bottom: 40px;\n  max-height: calc(100vh - 40px);\n  background: #222;\n  color: #fff;\n  overflow-y: auto;\n}\n\n.log-menu[hidden] {\n  display: none;\n}\n\n.log-menu tbody td {\n  padding: 2px 8px;\n}\n\n.log-menu tbody tr {\n  cursor: pointer;\n}\n\n.log-menu tbody tr:hover {\n  background: #444;\n}\n\n.log-menu tbody tr[hidden] {\n  display: none;\n}\n\n.button {\n  position: relative;\n  display: inline-block;\n  color: #fff;\n  margin: 8px 1px;\n  height: 24px;\n  line-height: 24px;\n  padding: 0 8px;\n  font-size: 14px;\n  cursor: pointer;\n  vertical-align: middle;\n  background-color: #444;\n  background-image: linear-gradient(rgba(0, 0, 0, 0), rgba(0, 0, 0, 0.2));\n  border-radius: 2px;\n  box-shadow: 1px 1px 1px rgba(0, 0, 0, 0.5), inset 0 1px 0 rgba(255, 255, 255, 0.2),\n    inset 0 0 2px rgba(255, 255, 255, 0.2);\n  text-shadow: 0 -1px 0 rgba(0, 0, 0, 0.4);\n  text-decoration: none;\n}\n\n.button:hover,\n.button:focus {\n  color: #fff;\n  text-decoration: none;\n  background-color: #555;\n}\n\n.notice {\n  display: inline-block;\n  margin: 8px;\n  font-size: 13px;\n  line-height: 24px;\n  vertical-align: middle;\n  color: #ffd24d;\n}\n\n.search {\n  appearance: none;\n  border: none;\n  border-radius: 2px;\n  background-image: linear-gradient(rgba(0, 0, 0, 0.2), rgba(0, 0, 0, 0));\n  box-shadow: inset 0 1px 0 rgba(0, 0, 0, 0.2), inset 0 0 2px rgba(0, 0, 0, 0.2);\n  padding: 2px 8px;\n  margin: 0;\n  line-height: 20px;\n  vertical-align: middle;\n  color: black;\n  width: auto;\n  height: auto;\n  font-size: 14px;\n}\n", a.append(o);
		let s = this.makeButton("CopyTuner", e, "_blank"), c = this.makeButton("Sync", "/copytuner", "_blank"), l = this.makeButton("Translations in this page", "javascript:void(0)");
		this.#t = document.createElement("input"), this.#t.type = "text", this.#t.classList.add("search"), this.#t.placeholder = "search", a.append(s, c, l, this.#t), this.#n = this.makeLogMenu(t), a.append(this.#n), n && this.appendSkippedNotice(), l.addEventListener("click", (e) => {
			e.preventDefault(), this.toggleLogMenu();
		}), this.#t.addEventListener("input", r(this.onSearch.bind(this), 250));
	}
	show() {
		this.#t.focus();
	}
	makeButton(e, t, n) {
		let r = document.createElement("a");
		return r.classList.add("button"), r.textContent = e, r.href = t, n && (r.target = n), r;
	}
	appendSkippedNotice() {
		let e = document.createElement("span");
		e.classList.add("notice"), e.textContent = "⚠ This page is too large for the overlay. Use \"Translations in this page\" to edit.", this.shadowRoot.append(e);
	}
	showLogMenu() {
		this.#n.hidden = !1;
	}
	toggleLogMenu() {
		this.#n.hidden = !this.#n.hidden;
	}
	makeLogMenu(e) {
		let t = document.createElement("div");
		t.classList.add("log-menu"), t.hidden = !0;
		let n = document.createElement("table"), r = document.createElement("tbody");
		for (let t of Object.keys(e).sort()) {
			let n = e[t];
			if (n === "") continue;
			let i = document.createElement("td");
			i.textContent = t;
			let a = document.createElement("td");
			a.textContent = n;
			let o = document.createElement("tr");
			o.dataset.key = t, o.addEventListener("click", ({ currentTarget: e }) => {
				let t = e;
				t.dataset.key && this.#e(t.dataset.key);
			}), o.append(i, a), r.append(o);
		}
		return n.append(r), t.append(n), t;
	}
	onSearch() {
		let e = this.#t.value.trim();
		this.showLogMenu();
		let t = [...this.#n.querySelectorAll("tr")];
		for (let n of t) n.hidden = !(e === "" || [...n.querySelectorAll("td")].some((t) => (t.textContent ?? "").includes(e)));
	}
}, a = class extends HTMLElement {
	dialog;
	#e = () => {};
	constructor() {
		super();
		let e = this.attachShadow({ mode: "open" }), t = document.createElement("style");
		t.textContent = "\n/* transform / filter / perspective / contain は置かない（理由は OVERLAY_STYLES のコメント参照） */\ndialog {\n  position: fixed;\n  inset: 0;\n  width: 100%;\n  height: 100%;\n  max-width: none;\n  max-height: none;\n  margin: 0;\n  border: none;\n  padding: 0;\n  background: transparent;\n  color: inherit;\n  overflow: visible;\n}\n\ndialog::backdrop {\n  background: transparent;\n}\n\n.toggle-button {\n  display: block;\n  position: fixed;\n  left: 0;\n  bottom: 0;\n  color: white;\n  background: black;\n  padding: 12px 16px;\n  border-radius: 0 10px 0 0;\n  opacity: 0;\n  transition: opacity 0.6s ease-in-out;\n  z-index: 10000;\n  font-size: 12px;\n  cursor: pointer;\n  text-decoration: none;\n}\n\n.toggle-button:hover {\n  opacity: 1;\n}\n\n@media screen and (max-width: 480px) {\n  .toggle-button {\n    display: none;\n  }\n}\n", e.append(t), this.dialog = document.createElement("dialog");
		let n = document.createElement("a");
		n.classList.add("toggle-button"), n.textContent = "Open CopyTuner", n.addEventListener("click", () => this.#e()), e.append(this.dialog, n);
	}
	set onToggle(e) {
		this.#e = e;
	}
};
customElements.define("copytuner-bar", i), customElements.define("copyray-overlay", t), customElements.define("copytuner-root", a);
var o = () => {
	let { url: e, data: t, keysSkipped: r } = window.CopyTuner, i = (t) => window.open(`${e}/blurbs/${t}/edit`), a = document.createElement("copytuner-root");
	document.body.append(a);
	let o = document.createElement("copytuner-bar"), s = document.createElement("copyray-overlay");
	s.onOpen = i, a.dialog.append(s, o), o.init({
		url: e,
		data: t,
		keysSkipped: !!r,
		onOpen: i
	});
	let c = () => {
		a.dialog.showModal(), s.show(), o.show();
	}, l = () => {
		a.dialog.close(), s.hide();
	}, u = () => a.dialog.open ? l() : c();
	a.onToggle = u, s.onClose = l, window.CopyTuner.toggle = u, a.dialog.addEventListener("close", () => {
		a.dialog.open || s.hide();
	}), document.addEventListener("keydown", (e) => {
		(n && e.metaKey || !n && e.ctrlKey) && e.shiftKey && e.key.toLowerCase() === "k" && u();
	}), console && console.log(`Ready to Copyray. Press ${n ? "cmd+shift+k" : "ctrl+shift+k"} to scan your UI.`);
};
document.readyState === "complete" || document.readyState !== "loading" ? o() : document.addEventListener("DOMContentLoaded", () => o());
//#endregion
