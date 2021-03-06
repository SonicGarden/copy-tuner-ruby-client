import KeyCode from 'keycode-js';
import Copyray from './copyray';
import { isMac } from './util';

const start = () => {
  const dataElement = document.getElementById('copy-tuner-data');
  const copyTunerUrl = dataElement.dataset.copyTunerUrl;
  const data = JSON.parse(
    document.getElementById('copy-tuner-data').dataset.copyTunerTranslationLog,
  );
  const copyray = new Copyray(copyTunerUrl, data);

  document.addEventListener('keydown', (event) => {
    if (copyray.isShowing && event.keyCode === KeyCode.KEY_ESCAPE) {
      copyray.hide();
      return;
    }

    if (
      ((isMac && event.metaKey) || (!isMac && event.ctrlKey)) &&
      event.shiftKey &&
      event.keyCode === KeyCode.KEY_K
    ) {
      copyray.toggle();
    }
  });

  if (console) {
    // eslint-disable-next-line no-console
    console.log(
      `Ready to Copyray. Press ${isMac ? 'cmd+shift+k' : 'ctrl+shift+k'} to scan your UI.`,
    );
  }

  window.copyray = copyray;
};

if (document.readyState === 'complete' || document.readyState !== 'loading') {
  start();
} else {
  document.addEventListener('DOMContentLoaded', start);
}
