// Copyright (c) 2020 Target Brands, Inc. All rights reserved.
//
// Use of this source code is governed by the LICENSE file in this repository.

import { App, Config, Elm, Flags, Session, Theme } from '../elm/Main';
import '../scss/style.scss';
import ClipboardJS from 'clipboard';

// Vela consts
const feedbackURL: string =
  'https://github.com/go-vela/community/issues/new/choose';
const docsURL: string = 'https://go-vela.github.io/docs';

// setup for session state
const storageKey: string = 'vela';
const storedSessionState: string | null = sessionStorage.getItem(storageKey);
const currentSessionState: Session | null = storedSessionState
  ? JSON.parse(storedSessionState)
  : null;

// setup for stored theme
const themeKey: string = 'vela-theme';
const defaultTheme: string = 'theme-dark';
const storedThemeState: string | null = localStorage.getItem(themeKey);
const currentThemeState: Theme =
  (storedThemeState as Theme) || (defaultTheme as Theme);

// Vela flags; configuration for bootstrapping Vela Elm UI
const flags: Flags = {
  isDev: process.env.NODE_ENV === 'development',
  velaAPI: process.env.VELA_API || '$VELA_API',
  velaFeedbackURL:
    process.env.VELA_FEEDBACK_URL ||
    envOrNull('VELA_FEEDBACK_URL', '$VELA_FEEDBACK_URL') ||
    feedbackURL,
  velaDocsURL:
    process.env.VELA_DOCS_URL ||
    envOrNull('VELA_DOCS_URL', '$VELA_DOCS_URL') ||
    docsURL,
  velaSession: currentSessionState || null,
  velaTheme: currentThemeState || (defaultTheme as Theme),
};

// create the configuration object for Elm
const config: Config = {
  node: null, // not passing an HTML node will let Elm take over the whole page
  flags: flags,
};

// bootstrap the app
const app: App = Elm.Main.init(config);

// subscribe to session events sent from Elm
app.ports.storeSession.subscribe(sessionMessage => {
  if (sessionMessage === null) {
    sessionStorage.removeItem(storageKey);
  } else {
    sessionStorage.setItem(storageKey, JSON.stringify(sessionMessage));
  }

  setTimeout(() => app.ports.onSessionChange.send(sessionMessage), 0);
});

app.ports.setTheme.subscribe(theme => {
  let body: HTMLElement = document.getElementsByTagName('body')[0];

  if (!body.classList.contains(theme)) {
    body.className = '';
    body.classList.add(theme);
  }

  localStorage.setItem(themeKey, theme);
  setTimeout(() => app.ports.onThemeChange.send(theme), 0);
});

app.ports.setFavicon.subscribe(function (url) {
  var oldIcon = document.getElementById('favicon');
  var newIcon = document.createElement('link');
  newIcon.id = 'favicon';
  newIcon.rel = 'shortcut icon';
  newIcon.href = url;
  if (oldIcon) {
    document.head.removeChild(oldIcon);
  }
  document.head.appendChild(newIcon);
});

app.ports.base64Decode.subscribe(function (args) {
  try {
    let msg = args[0];
    let decoded = atob(msg);
    args[0] = decoded;
    setTimeout(() => app.ports.onBase64Decode.send(args), 0);
  } catch (err) {
    console.log('could not base64 decode string: ', err);
  }
});

// initialize clipboard.js
new ClipboardJS('.copy-button');

/**
 * envOrNull is a basic helper that returns a substituted
 * environment variable or null
 *
 * @param env the env variable to be substituted, sans "$" prefix
 * @param subst the substituted variable (or not)
 */
function envOrNull(env: string, subst: string): string | null {
  // substituted value is empty
  if (!subst || !subst.trim()) {
    return null;
  }

  // value was not substituted; ignore
  if (subst.indexOf(env) !== -1) {
    return null;
  }

  // value was substituted, return it
  return subst;
}
