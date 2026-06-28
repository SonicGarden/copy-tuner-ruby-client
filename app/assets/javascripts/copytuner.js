//#region src/styles.ts
var e = navigator.platform.toUpperCase().includes("MAC"), t = (e) => !!(e.offsetWidth || e.offsetHeight || e.getClientRects().length > 0), n = (e) => {
	let t = e.getBoundingClientRect();
	return {
		top: t.top + (window.pageYOffset - document.documentElement.clientTop),
		left: t.left + (window.pageXOffset - document.documentElement.clientLeft)
	};
}, r = (e) => {
	if (!t(e)) return null;
	let r = n(e);
	return r.right = r.left + e.offsetWidth, r.bottom = r.top + e.offsetHeight, {
		left: r.left,
		top: r.top,
		width: r.right - r.left,
		height: r.bottom - r.top
	};
}, i = (e, t) => {
	let n;
	return (...r) => {
		clearTimeout(n), n = setTimeout(() => e(...r), t);
	};
}, a = () => Array.from(document.querySelectorAll("[data-copyray-key]")).map((e) => ({
	keys: (e.getAttribute("data-copyray-key") ?? "").split(",").filter(Boolean),
	element: e
})), o = class extends HTMLElement {
	#e = () => {};
	#t = () => {};
	#n;
	#r;
	#i;
	constructor() {
		super();
		let e = this.attachShadow({ mode: "open" }), t = document.createElement("style");
		t.textContent = "\n:host {\n  position: absolute;\n  top: 0;\n  left: 0;\n  width: 0;\n  height: 0;\n}\n\n:host([hidden]) {\n  display: none;\n}\n\n.backdrop {\n  position: fixed;\n  inset: 0;\n  background-image: radial-gradient(\n    ellipse farthest-corner at center,\n    rgba(0, 0, 0, 0.4) 10%,\n    rgba(0, 0, 0, 0.8) 100%\n  );\n  z-index: 9000;\n}\n\n.specimen {\n  position: absolute;\n  background: rgba(255, 50, 50, 0.1);\n  outline: 1px solid rgba(255, 50, 50, 0.8);\n  outline-offset: -1px;\n  color: #666;\n  font-family: 'Helvetica Neue', sans-serif;\n  font-size: 13px;\n  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.7);\n  z-index: 2000000000;\n}\n\n.specimen:hover {\n  cursor: pointer;\n  background: rgba(255, 50, 50, 0.4);\n}\n\n.specimen-handle {\n  float: left;\n  margin: 0 2px 2px 0;\n  background: rgba(255, 50, 50, 0.8);\n  padding: 0 3px;\n  color: #fff;\n  font-size: 10px;\n  cursor: pointer;\n}\n\n.toggle-button {\n  display: block;\n  position: fixed;\n  left: 0;\n  bottom: 0;\n  color: white;\n  background: black;\n  padding: 12px 16px;\n  border-radius: 0 10px 0 0;\n  opacity: 0;\n  transition: opacity 0.6s ease-in-out;\n  z-index: 10000;\n  font-size: 12px;\n  cursor: pointer;\n  text-decoration: none;\n}\n\n.toggle-button:hover {\n  opacity: 1;\n}\n\n@media screen and (max-width: 480px) {\n  .toggle-button {\n    display: none;\n  }\n}\n", e.append(t), this.#n = document.createElement("div"), this.#n.classList.add("backdrop"), this.#n.addEventListener("click", () => this.hide()), this.#r = document.createElement("div"), this.#r.classList.add("specimens"), this.#i = document.createElement("a"), this.#i.classList.add("toggle-button"), this.#i.textContent = "Open CopyTuner", this.#i.addEventListener("click", () => this.#t()), e.append(this.#n, this.#r, this.#i), this.hide();
	}
	set onOpen(e) {
		this.#e = e;
	}
	set onToggle(e) {
		this.#t = e;
	}
	get isShowing() {
		return !this.#n.hidden;
	}
	show() {
		this.reset(), this.#n.hidden = !1;
		for (let { element: e, keys: t } of a()) {
			let n = this.makeBox(e, t);
			n && this.#r.append(n);
		}
	}
	hide() {
		this.reset(), this.#n.hidden = !0;
	}
	reset() {
		this.#r.replaceChildren();
	}
	makeBox(e, t) {
		let n = r(e);
		if (n === null) return null;
		let i = document.createElement("div");
		i.classList.add("specimen"), i.style.left = `${n.left}px`, i.style.top = `${n.top}px`, i.style.width = `${n.width}px`, i.style.height = `${n.height}px`;
		let { position: a, top: o, left: s } = getComputedStyle(e);
		a === "fixed" && (i.style.position = "fixed", i.style.top = o, i.style.left = s), i.addEventListener("click", () => this.#e(t[0]));
		for (let e of t) i.append(this.makeLabel(e));
		return i;
	}
	makeLabel(e) {
		let t = document.createElement("div");
		return t.classList.add("specimen-handle"), t.textContent = e, t.addEventListener("click", (t) => {
			t.stopPropagation(), this.#e(e);
		}), t;
	}
}, s = class extends HTMLElement {
	#e = () => {};
	#t;
	#n;
	constructor() {
		super(), this.attachShadow({ mode: "open" });
	}
	connectedCallback() {
		this.hidden = !0;
	}
	init({ url: e, data: t, keysSkipped: n, onOpen: r }) {
		this.#e = r;
		let a = this.shadowRoot, o = document.createElement("style");
		o.textContent = "\n:host {\n  position: fixed;\n  left: 0;\n  right: 0;\n  bottom: 0;\n  height: 40px;\n  padding: 0 8px;\n  background: #222;\n  font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;\n  font-weight: 200;\n  color: #fff;\n  z-index: 2147483647;\n  box-shadow: 0 -1px 0 rgba(255, 255, 255, 0.1), inset 0 2px 6px rgba(0, 0, 0, 0.8);\n  background-image: linear-gradient(rgba(0, 0, 0, 0), rgba(0, 0, 0, 0.3));\n  box-sizing: border-box;\n}\n\n:host([hidden]) {\n  display: none;\n}\n\n.log-menu {\n  position: fixed;\n  left: 0;\n  right: 0;\n  bottom: 40px;\n  max-height: calc(100vh - 40px);\n  background: #222;\n  color: #fff;\n  overflow-y: auto;\n}\n\n.log-menu[hidden] {\n  display: none;\n}\n\n.log-menu tbody td {\n  padding: 2px 8px;\n}\n\n.log-menu tbody tr {\n  cursor: pointer;\n}\n\n.log-menu tbody tr:hover {\n  background: #444;\n}\n\n.log-menu tbody tr[hidden] {\n  display: none;\n}\n\n.button {\n  position: relative;\n  display: inline-block;\n  color: #fff;\n  margin: 8px 1px;\n  height: 24px;\n  line-height: 24px;\n  padding: 0 8px;\n  font-size: 14px;\n  cursor: pointer;\n  vertical-align: middle;\n  background-color: #444;\n  background-image: linear-gradient(rgba(0, 0, 0, 0), rgba(0, 0, 0, 0.2));\n  border-radius: 2px;\n  box-shadow: 1px 1px 1px rgba(0, 0, 0, 0.5), inset 0 1px 0 rgba(255, 255, 255, 0.2),\n    inset 0 0 2px rgba(255, 255, 255, 0.2);\n  text-shadow: 0 -1px 0 rgba(0, 0, 0, 0.4);\n  text-decoration: none;\n}\n\n.button:hover,\n.button:focus {\n  color: #fff;\n  text-decoration: none;\n  background-color: #555;\n}\n\n.notice {\n  display: inline-block;\n  margin: 8px;\n  font-size: 13px;\n  line-height: 24px;\n  vertical-align: middle;\n  color: #ffd24d;\n}\n\n.search {\n  appearance: none;\n  border: none;\n  border-radius: 2px;\n  background-image: linear-gradient(rgba(0, 0, 0, 0.2), rgba(0, 0, 0, 0));\n  box-shadow: inset 0 1px 0 rgba(0, 0, 0, 0.2), inset 0 0 2px rgba(0, 0, 0, 0.2);\n  padding: 2px 8px;\n  margin: 0;\n  line-height: 20px;\n  vertical-align: middle;\n  color: black;\n  width: auto;\n  height: auto;\n  font-size: 14px;\n}\n", a.append(o);
		let s = this.makeButton("CopyTuner", e, "_blank"), c = this.makeButton("Sync", "/copytuner", "_blank"), l = this.makeButton("Translations in this page", "javascript:void(0)");
		this.#t = document.createElement("input"), this.#t.type = "text", this.#t.classList.add("search"), this.#t.placeholder = "search", a.append(s, c, l, this.#t), this.#n = this.makeLogMenu(t), a.append(this.#n), n && this.appendSkippedNotice(), l.addEventListener("click", (e) => {
			e.preventDefault(), this.toggleLogMenu();
		}), this.#t.addEventListener("input", i(this.onSearch.bind(this), 250));
	}
	show() {
		this.hidden = !1, this.#t.focus();
	}
	hide() {
		this.hidden = !0;
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
};
customElements.define("copytuner-bar", s), customElements.define("copyray-overlay", o);
var c = () => {
	let { url: t, data: n, keysSkipped: r } = window.CopyTuner, i = (e) => window.open(`${t}/blurbs/${e}/edit`), a = document.createElement("copytuner-bar");
	document.body.append(a), a.init({
		url: t,
		data: n,
		keysSkipped: !!r,
		onOpen: i
	});
	let o = document.createElement("copyray-overlay");
	o.onOpen = i, document.body.append(o);
	let s = () => {
		o.show(), a.show();
	}, c = () => {
		o.hide(), a.hide();
	}, l = () => o.isShowing ? c() : s();
	o.onToggle = l, window.CopyTuner.toggle = l, document.addEventListener("keydown", (t) => {
		if (o.isShowing && ["Escape", "Esc"].includes(t.key)) {
			c();
			return;
		}
		(e && t.metaKey || !e && t.ctrlKey) && t.shiftKey && t.key.toLowerCase() === "k" && l();
	}), console && console.log(`Ready to Copyray. Press ${e ? "cmd+shift+k" : "ctrl+shift+k"} to scan your UI.`);
};
document.readyState === "complete" || document.readyState !== "loading" ? c() : document.addEventListener("DOMContentLoaded", () => c());
//#endregion
