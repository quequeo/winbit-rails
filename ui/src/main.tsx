import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import 'react-day-picker/style.css'
import App from './App.tsx'

// Show [DEV] in the browser tab when running locally (even if served from Rails public/).
const isLocalHost = ['localhost', '127.0.0.1', '0.0.0.0'].includes(globalThis?.location?.hostname)
if (import.meta.env.DEV || isLocalHost) {
  document.title = 'Winbit Admin v1.0.0 [DEV]'
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
