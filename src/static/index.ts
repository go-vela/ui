// SPDX-License-Identifier: Apache-2.0

// import types
import * as ClipboardJS from 'clipboard';
import * as d3 from 'd3';
import { Graphviz } from '@hpcc-js/wasm-graphviz';

import { Elm } from '../elm/Main.elm';
import '../scss/style.scss';
import { App, Config, Flags, Theme } from './index.d';
import * as Graph from './graph';

// Vela consts
const feedbackURL: string =
  'https://github.com/go-vela/community/issues/new/choose';
const docsURL: string = 'https://go-vela.github.io/docs';
const defaultLogBytesLimit: number = 2000000; // 2mb
const maximumBuildLimit: number = 30;
const maximumStarlarkExecLimit: number = 99999;
const scheduleAllowlist: string = '*';

// setup for auth redirect
const redirectKey: string = 'vela-redirect';
const storedRedirectKey: string | null = localStorage.getItem(redirectKey);
const currentRedirectKey: string | null = storedRedirectKey;

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
  velaTheme: currentThemeState || (defaultTheme as Theme),
  velaRedirect: currentRedirectKey || '',
  velaLogBytesLimit: Number(
    process.env.VELA_LOG_BYTES_LIMIT ||
      envOrNull('VELA_LOG_BYTES_LIMIT', '$VELA_LOG_BYTES_LIMIT') ||
      defaultLogBytesLimit,
  ),
  velaMaxBuildLimit: Number(
    process.env.VELA_MAX_BUILD_LIMIT ||
      envOrNull('VELA_MAX_BUILD_LIMIT', '$VELA_MAX_BUILD_LIMIT') ||
      maximumBuildLimit,
  ),
  velaMaxStarlarkExecLimit: Number(
    process.env.VELA_MAX_STARLARK_EXEC_LIMIT ||
      envOrNull(
        'VELA_MAX_STARLARK_EXEC_LIMIT',
        '$VELA_MAX_STARLARK_EXEC_LIMIT',
      ) ||
      maximumStarlarkExecLimit,
  ),
  velaScheduleAllowlist:
    (window as any).__velaEnv?.VELA_SCHEDULE_ALLOWLIST ||
    (window.Cypress && window.Cypress.env('VELA_SCHEDULE_ALLOWLIST')) ||
    process.env.VELA_SCHEDULE_ALLOWLIST ||
    envOrNull('VELA_SCHEDULE_ALLOWLIST', '$VELA_SCHEDULE_ALLOWLIST') ||
    scheduleAllowlist,
};

// create the configuration object for Elm
const config: Config = {
  node: null, // not passing an HTML node will let Elm take over the whole page
  flags: flags,
};

// bootstrap the app
const app: App = Elm.Main.init(config);

app.ports.setTheme.subscribe(theme => {
  let body: HTMLElement = document.getElementsByTagName('body')[0];

  const applyTheme = (t: string) => {
    if (!body.classList.contains(t)) {
      body.className = '';
      body.classList.add(t);
    }
  };

  if (theme === 'theme-system') {
    // apply the current system preference immediately
    const isDark =
      window.matchMedia &&
      window.matchMedia('(prefers-color-scheme: dark)').matches;
    const applied = isDark ? 'theme-dark' : 'theme-light';
    applyTheme(applied);

    // listen for changes to the system preference and update accordingly.
    const mql = window.matchMedia('(prefers-color-scheme: dark)');
    const listener = (e: MediaQueryListEvent) => {
      const nowApplied = e.matches ? 'theme-dark' : 'theme-light';
      applyTheme(nowApplied);
      // notify Elm that the selection remains 'theme-system' (do not send the resolved theme)
      setTimeout(() => app.ports.onThemeChange.send(theme), 0);
    };

    // listen for changes to the media query
    (mql as any).addEventListener('change', listener);

    // persist the user's selection of 'theme-system' (not the resolved light/dark)
    localStorage.setItem(themeKey, theme);

    // notify Elm that the selection is 'theme-system' (do not send the resolved theme)
    setTimeout(() => app.ports.onThemeChange.send(theme), 0);
  } else {
    // explicit light or dark
    applyTheme(theme);
    localStorage.setItem(themeKey, theme);
    setTimeout(() => app.ports.onThemeChange.send(theme), 0);
  }
});

app.ports.setRedirect.subscribe(redirectMessage => {
  if (redirectMessage === null) {
    localStorage.removeItem(redirectKey);
  } else {
    localStorage.setItem(redirectKey, redirectMessage);
  }
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

// track rendering options globally to help determine draw logic
var opts = {
  drawn: false,
  currentBuild: -1,
  sameBuild: false,
  freshDraw: false,
  contentFilter: '',
  onGraphInteraction: {},
};

app.ports.renderBuildGraph.subscribe(function (graphData) {
  if (!graphData) {
    return;
  }

  const graphviz = Graphviz.load().then(res => {
    var content = res.layout(graphData.dot, 'svg', 'dot');

    // construct graph building options
    // reset the draw state when the build changes

    // what if the first freshDraw is skipped, and the next draw is a fresh
    // but we never reset this drawn to false
    if (opts.currentBuild !== graphData.buildID || graphData.freshDraw) {
      opts.drawn = false;
    }

    opts.sameBuild = opts.currentBuild === graphData.buildID;
    opts.freshDraw = graphData.freshDraw;
    opts.contentFilter = graphData.filter;

    // track the currently drawn build
    opts.currentBuild = graphData.buildID;

    // graph interactivity
    opts.onGraphInteraction = app.ports.onGraphInteraction;

    // dispatch the draw command to avoid elm/js rendering race condition
    setTimeout(() => {
      opts.drawn = Graph.drawGraph(opts, content);
    }, 0);
  });
});
