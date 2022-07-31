import { CopytunerInspector, type CopytunerData } from './copyray'

declare global {
  interface Window {
    CopyTuner: {
      url: string
      data: CopytunerData
    }
  }
}

import './copyray.css'

const start = () => {
  const { data } = window.CopyTuner

  const inspector = new CopytunerInspector()
  inspector.blurbs = Object.entries(data).map(([key, content]) => ({
    key,
    content,
  }))
  document.body.append(inspector)
}

if (document.readyState === 'complete' || document.readyState !== 'loading') {
  start()
} else {
  document.addEventListener('DOMContentLoaded', () => start())
}
