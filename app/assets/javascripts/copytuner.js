//#region src/util.ts
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
}, a = "copy-tuner-hidden", o = class {
	constructor(e, t, n, r = !1) {
		this.element = e, this.data = t, this.callback = n, this.searchBoxElement = e.querySelector(".js-copy-tuner-bar-search"), this.logMenuElement = this.makeLogMenu(), this.element.append(this.logMenuElement), r && this.appendSkippedNotice(), this.addHandler();
	}
	appendSkippedNotice() {
		let e = document.createElement("span");
		e.classList.add("copy-tuner-bar__notice"), e.textContent = "⚠ This page is too large for the overlay. Use \"Translations in this page\" to edit.", this.element.append(e);
	}
	addHandler() {
		this.element.querySelector(".js-copy-tuner-bar-open-log").addEventListener("click", (e) => {
			e.preventDefault(), this.toggleLogMenu();
		}), this.searchBoxElement.addEventListener("input", i(this.onKeyup.bind(this), 250));
	}
	show() {
		this.element.classList.remove(a), this.searchBoxElement.focus();
	}
	hide() {
		this.element.classList.add(a);
	}
	showLogMenu() {
		this.logMenuElement.classList.remove(a);
	}
	toggleLogMenu() {
		this.logMenuElement.classList.toggle(a);
	}
	makeLogMenu() {
		let e = document.createElement("div");
		e.setAttribute("id", "copy-tuner-bar-log-menu"), e.classList.add(a);
		let t = document.createElement("table"), n = document.createElement("tbody");
		n.classList.remove("is-not-initialized");
		for (let e of Object.keys(this.data).sort()) {
			let t = this.data[e];
			if (t === "") continue;
			let r = document.createElement("td");
			r.textContent = e;
			let i = document.createElement("td");
			i.textContent = t;
			let a = document.createElement("tr");
			a.classList.add("copy-tuner-bar-log-menu__row"), a.dataset.key = e, a.addEventListener("click", ({ currentTarget: e }) => {
				this.callback(e.dataset.key);
			}), a.append(r), a.append(i), n.append(a);
		}
		return t.append(n), e.append(t), e;
	}
	onKeyup({ target: e }) {
		let t = e.value.trim();
		this.showLogMenu();
		let n = [...this.logMenuElement.querySelectorAll("tr")];
		for (let e of n) {
			let n = t === "" || [...e.querySelectorAll("td")].some((e) => e.textContent.includes(t));
			e.classList.toggle(a, !n);
		}
	}
}, s = 2e9, c = class {
	constructor(e, t, n) {
		this.element = e, this.keys = t, this.callback = n;
	}
	show() {
		this.box = this.makeBox(), this.box !== null && (this.box.addEventListener("click", () => {
			this.callback(this.keys[0]);
		}), document.body.append(this.box));
	}
	remove() {
		this.box &&= (this.box.remove(), null);
	}
	makeBox() {
		let e = document.createElement("div");
		e.classList.add("copyray-specimen"), e.classList.add("Specimen");
		let t = r(this.element);
		if (t === null) return null;
		for (let n of Object.keys(t)) {
			let r = t[n];
			e.style[n] = `${r}px`;
		}
		e.style.zIndex = s;
		let { position: n, top: i, left: a } = getComputedStyle(this.element);
		n === "fixed" && (this.box.style.position = "fixed", this.box.style.top = `${i}px`, this.box.style.left = `${a}px`);
		for (let t of this.keys) e.append(this.makeLabel(t));
		return e;
	}
	makeLabel(e) {
		let t = document.createElement("div");
		return t.classList.add("copyray-specimen-handle"), t.classList.add("Specimen"), t.textContent = e, t.addEventListener("click", (t) => {
			t.stopPropagation(), this.callback(e);
		}), t;
	}
}, l = () => Array.from(document.querySelectorAll("[data-copyray-key]")).map((e) => ({
	keys: (e.getAttribute("data-copyray-key") ?? "").split(",").filter(Boolean),
	element: e
})), u = class {
	constructor(e, t, n = !1) {
		this.baseUrl = e, this.data = t, this.isShowing = !1, this.specimens = [], this.overlay = this.makeOverlay(), this.toggleButton = this.makeToggleButton(), this.boundOpen = this.open.bind(this), this.copyTunerBar = new o(document.querySelector("#copy-tuner-bar"), this.data, this.boundOpen, n);
	}
	show() {
		this.reset(), document.body.append(this.overlay), this.makeSpecimens();
		for (let e of this.specimens) e.show();
		this.copyTunerBar.show(), this.isShowing = !0;
	}
	hide() {
		this.overlay.remove(), this.reset(), this.copyTunerBar.hide(), this.isShowing = !1;
	}
	toggle() {
		this.isShowing ? this.hide() : this.show();
	}
	open(e) {
		window.open(`${this.baseUrl}/blurbs/${e}/edit`);
	}
	makeSpecimens() {
		for (let { element: e, keys: t } of l()) this.specimens.push(new c(e, t, this.boundOpen));
	}
	makeToggleButton() {
		let e = document.createElement("a");
		return e.addEventListener("click", () => {
			this.show();
		}), e.classList.add("copyray-toggle-button"), e.classList.add("hidden-on-mobile"), e.textContent = "Open CopyTuner", document.body.append(e), e;
	}
	makeOverlay() {
		let e = document.createElement("div");
		return e.setAttribute("id", "copyray-overlay"), e.addEventListener("click", () => this.hide()), e;
	}
	reset() {
		for (let e of this.specimens) e.remove();
	}
}, d = (e) => {
	let t = document.createElement("div");
	t.id = "copy-tuner-bar", t.classList.add("copy-tuner-hidden"), t.innerHTML = `
    <a class="copy-tuner-bar-button" target="_blank" href="${e}">CopyTuner</a>
    <a href="/copytuner" target="_blank" class="copy-tuner-bar-button">Sync</a>
    <a href="javascript:void(0)" class="copy-tuner-bar-open-log copy-tuner-bar-button js-copy-tuner-bar-open-log">Translations in this page</a>
    <input type="text" class="copy-tuner-bar__search js-copy-tuner-bar-search" placeholder="search">
  `, document.body.append(t);
}, f = () => {
	let { url: t, data: n, keysSkipped: r } = window.CopyTuner;
	d(t);
	let i = new u(t, n, !!r);
	window.CopyTuner.toggle = () => i.toggle(), document.addEventListener("keydown", (t) => {
		if (i.isShowing && ["Escape", "Esc"].includes(t.key)) {
			i.hide();
			return;
		}
		(e && t.metaKey || !e && t.ctrlKey) && t.shiftKey && t.key.toLowerCase() === "k" && i.toggle();
	}), console && console.log(`Ready to Copyray. Press ${e ? "cmd+shift+k" : "ctrl+shift+k"} to scan your UI.`);
};
document.readyState === "complete" || document.readyState !== "loading" ? f() : document.addEventListener("DOMContentLoaded", () => f());
//#endregion
