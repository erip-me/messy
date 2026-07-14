import { h, render } from 'preact';
import { Widget } from './widget';
import { initApi, identify } from './services/api';
import type { MessyConfig } from './types';

declare global {
  interface Window {
    MessyConfig?: MessyConfig;
    MessyChat?: {
      identify: (params: { email: string; first_name?: string; last_name?: string; custom_attributes?: Record<string, unknown>; user_hash?: string }) => Promise<void>;
    };
  }
}

(function () {
  console.log('[Messy] Widget script loaded');

  const config = window.MessyConfig;
  if (!config || !config.widgetId) {
    console.warn('[Messy] Missing window.MessyConfig.widgetId — widget will not initialize');
    return;
  }

  console.log('[Messy] Initializing with widgetId:', config.widgetId);
  initApi(config.widgetId);

  window.MessyChat = {
    identify: (params) => identify(params),
  };

  const host = document.createElement('div');
  host.id = 'messy-chat-widget';
  host.style.cssText = 'all: initial; position: fixed; z-index: 2147483647;';
  document.body.appendChild(host);

  if (host.attachShadow) {
    const shadow = host.attachShadow({ mode: 'open' });
    const container = document.createElement('div');
    shadow.appendChild(container);

    const style = document.createElement('style');
    style.textContent = `
      :host { all: initial; }
      *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    `;
    shadow.appendChild(style);

    render(h(Widget, { config }), container);
  } else {
    render(h(Widget, { config }), host);
  }

  console.log('[Messy] Widget rendered');
})();
