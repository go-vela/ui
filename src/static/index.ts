// Copyright (c) 2021 Target Brands, Inc. All rights reserved.
//
// Use of this source code is governed by the LICENSE file in this repository.

// import types
import * as ClipboardJS from 'clipboard';
import * as d3 from 'd3';

// @ts-ignore // false negative module warning
import { Elm } from '../elm/Main.elm';
import '../scss/style.scss';
import { App, Config, Flags, Theme } from './index.d';

// Vela consts
const feedbackURL: string =
  'https://github.com/go-vela/community/issues/new/choose';
const docsURL: string = 'https://go-vela.github.io/docs';
const defaultLogBytesLimit: number = 2000000; // 2mb

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

  if (!body.classList.contains(theme)) {
    body.className = '';
    body.classList.add(theme);
  }

  localStorage.setItem(themeKey, theme);
  setTimeout(() => app.ports.onThemeChange.send(theme), 0);
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



let worker;
var workerPromise;

app.ports.renderBuildGraph.subscribe(function (dot) {
  if (typeof(Worker) === "undefined") {
    console.log("sorry, your browser does not support the Worker API, unable to compile graphviz.")
  }

  if (!worker) {
    workerPromise = runGraphvizWorker(dot);
  }
  // how do we wait on the above promise?
  worker.postMessage({ eventType: 'LAYOUT', dot: dot });
});


// runGraphvizWorker
function runGraphvizWorker(dot) {
  return new Promise((resolve, reject) => {
    // @ts-ignore // false negative - standalone support for import.meta added in Parcel v2 - https://parceljs.org/blog/rc0/#support-for-standalone-import.meta
    worker = new Worker(new URL('./graphviz.worker.js', import.meta.url), {
      type: 'module',
    });
    
    // use the worker to initialize the worker
    worker.postMessage({ eventType: 'INIT' });

    worker.addEventListener('message', function (event) {
      const { eventType } = event.data;
      if (eventType === 'DRAW') {
        const { drawContent } = event.data;
        // draw occurs in the main thread 
        //  because web workers do not have access to the DOM
        draw(drawContent);
      }
    });
    worker.addEventListener('error', function (error) {
      reject(error);
    });
    console.log("done creating promise")
  });
}

function draw(content) {
  console.log('drawing')
  var svg = d3.select('.build-graph');
  var g = d3.select('g.node_mousedown');
  console.log(svg)
  if (g.empty()) {
    console.log("g empty")
    // console.log(g)
    g = svg.append('g').attr('class', 'node_mousedown');
    svg.on('mousedown', (e, d) => {
      // stop propagation on buttons and ctrl+click
      if (e.button || e.ctrlKey) {
        e.stopImmediatePropagation();
      }
    });
    // console.log(g)
  }
  svg = g;
  console.log(svg)
  console.log(svg.node())
  svg.html(content);
  svg.selectAll('title').remove();
  svg.selectAll('*').attr('xlink:title', null);
  var bbox = svg.node().getBBox();
  const VIEWBOX_PADDING = { x1: 20, x2: 40, y1: 20, y2: 40 };
  var parent = d3.select(svg.node().parentNode);
  parent.attr(
    'viewBox',
    '' +
      (bbox.x - VIEWBOX_PADDING.x1) +
      ' ' +
      (bbox.y - VIEWBOX_PADDING.y1) +
      ' ' +
      (bbox.width + VIEWBOX_PADDING.x2) +
      ' ' +
      (bbox.height + VIEWBOX_PADDING.y2),
  );
}
