// 各 custom element の Shadow root に <style> として注入する CSS。
// Shadow DOM のスタイル隔離が効くため、旧 copyray.css にあった #copyray-overlay * のグローバルリセットは不要。

// ツールバー（<copytuner-bar>）のスタイル。:host にバー本体のレイアウトを定義する。
export const BAR_STYLES = `
:host {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  height: 40px;
  padding: 0 8px;
  background: #222;
  font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
  font-weight: 200;
  color: #fff;
  z-index: 2147483647;
  box-shadow: 0 -1px 0 rgba(255, 255, 255, 0.1), inset 0 2px 6px rgba(0, 0, 0, 0.8);
  background-image: linear-gradient(rgba(0, 0, 0, 0), rgba(0, 0, 0, 0.3));
  box-sizing: border-box;
}

:host([hidden]) {
  display: none;
}

.log-menu {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 40px;
  max-height: calc(100vh - 40px);
  background: #222;
  color: #fff;
  overflow-y: auto;
}

.log-menu[hidden] {
  display: none;
}

.log-menu tbody td {
  padding: 2px 8px;
}

.log-menu tbody tr {
  cursor: pointer;
}

.log-menu tbody tr:hover {
  background: #444;
}

.log-menu tbody tr[hidden] {
  display: none;
}

.button {
  position: relative;
  display: inline-block;
  color: #fff;
  margin: 8px 1px;
  height: 24px;
  line-height: 24px;
  padding: 0 8px;
  font-size: 14px;
  cursor: pointer;
  vertical-align: middle;
  background-color: #444;
  background-image: linear-gradient(rgba(0, 0, 0, 0), rgba(0, 0, 0, 0.2));
  border-radius: 2px;
  box-shadow: 1px 1px 1px rgba(0, 0, 0, 0.5), inset 0 1px 0 rgba(255, 255, 255, 0.2),
    inset 0 0 2px rgba(255, 255, 255, 0.2);
  text-shadow: 0 -1px 0 rgba(0, 0, 0, 0.4);
  text-decoration: none;
}

.button:hover,
.button:focus {
  color: #fff;
  text-decoration: none;
  background-color: #555;
}

.notice {
  display: inline-block;
  margin: 8px;
  font-size: 13px;
  line-height: 24px;
  vertical-align: middle;
  color: #ffd24d;
}

.search {
  appearance: none;
  border: none;
  border-radius: 2px;
  background-image: linear-gradient(rgba(0, 0, 0, 0.2), rgba(0, 0, 0, 0));
  box-shadow: inset 0 1px 0 rgba(0, 0, 0, 0.2), inset 0 0 2px rgba(0, 0, 0, 0.2);
  padding: 2px 8px;
  margin: 0;
  line-height: 20px;
  vertical-align: middle;
  color: black;
  width: auto;
  height: auto;
  font-size: 14px;
}
`

// オーバーレイ（<copyray-overlay>）のスタイル。
// :host はドキュメント原点基準（position: absolute; top/left: 0）にして、
// 子の specimen を computeBoundingBox のページ座標で absolute 配置できるようにする。
// 背景の暗転（.backdrop）だけは viewport 固定（fixed）にする。
export const OVERLAY_STYLES = `
:host {
  position: absolute;
  top: 0;
  left: 0;
  width: 0;
  height: 0;
}

:host([hidden]) {
  display: none;
}

.backdrop {
  position: fixed;
  inset: 0;
  background-image: radial-gradient(
    ellipse farthest-corner at center,
    rgba(0, 0, 0, 0.4) 10%,
    rgba(0, 0, 0, 0.8) 100%
  );
  z-index: 9000;
}

.specimen {
  position: absolute;
  background: rgba(255, 50, 50, 0.1);
  outline: 1px solid rgba(255, 50, 50, 0.8);
  outline-offset: -1px;
  color: #666;
  font-family: 'Helvetica Neue', sans-serif;
  font-size: 13px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.7);
  z-index: 2000000000;
}

.specimen:hover {
  cursor: pointer;
  background: rgba(255, 50, 50, 0.4);
}

.specimen-handle {
  float: left;
  margin: 0 2px 2px 0;
  background: rgba(255, 50, 50, 0.8);
  padding: 0 3px;
  color: #fff;
  font-size: 10px;
  cursor: pointer;
}

.toggle-button {
  display: block;
  position: fixed;
  left: 0;
  bottom: 0;
  color: white;
  background: black;
  padding: 12px 16px;
  border-radius: 0 10px 0 0;
  opacity: 0;
  transition: opacity 0.6s ease-in-out;
  z-index: 10000;
  font-size: 12px;
  cursor: pointer;
  text-decoration: none;
}

.toggle-button:hover {
  opacity: 1;
}

@media screen and (max-width: 480px) {
  .toggle-button {
    display: none;
  }
}
`
