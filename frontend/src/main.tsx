if (import.meta.env.DEV) {
  import("react-grab");
}

import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { Provider } from 'react-redux'
import { PersistGate } from 'redux-persist/integration/react'
import { store, persistor } from './store'
import App from './App'
import './index.css'
import { initTheme } from './hooks/useTheme'
import { initAnalytics } from './lib/analytics'

// Apply the saved (or OS) theme before first paint to avoid a flash.
initTheme()

// Boot PostHog (no-op unless POSTHOG_KEY is configured).
initAnalytics()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Provider store={store}>
      <PersistGate loading={null} persistor={persistor}>
        <App />
      </PersistGate>
    </Provider>
  </StrictMode>,
)