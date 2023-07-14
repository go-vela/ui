// Copyright (c) 2022 Target Brands, Inc. All rights reserved.
//
// Use of this source code is governed by the LICENSE file in this repository.

// import types
import * as ClipboardJS from 'clipboard';
import { Console } from 'console';
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
const maximumBuildLimit: number = 30;
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
      envOrNull('VELA_MAX_BUILD_LIMIT', 'VELA_MAX_BUILD_LIMIT') ||
      maximumBuildLimit,
  ),

  velaScheduleAllowlist:
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

// variables for graphviz processing
let worker;
var workerPromise;

app.ports.renderBuildGraph.subscribe(function (dot) {
  if (typeof Worker === 'undefined') {
    console.log(
      'sorry, unable to compile graphviz, your browser does not support the Worker API',
    );
    return;
  }

  if (!worker) {
    workerPromise = runGraphvizWorker(dot);
  }
  // how do we wait on the above promise?
  worker.postMessage({ eventType: 'LAYOUT', dot: dot });
});

// runGraphvizWorker
function runGraphvizWorker(dot) {
  console.log('processing DOT graph using graphviz');
  console.log(dot);

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

    console.log('graphviz worker dispatched');
  });
}

function draw(content) {
  console.log('running draw(content)');

  console.log('fetching .build-graph');
  var buildGraphElement = d3.select('.build-graph');

  // enabling zoom causes the viewbox to act crazy when you click around
  console.log('enabling d3 zoom');

  let w = 400;
  let h = 400;

  buildGraphElement.call(
    d3
      .zoom()
      .scaleExtent([0.1, Infinity])
      // .translateExtent([[0, 0], [w, h]])
      // .extent([[0, 0], [w, h]])
      .on('zoom', zoomed),
  );

  function zoomed(event) {
    var g = d3.select('.build-graph g');
    g.attr('transform', event.transform);
  }

  console.log('grabbing g.node_mousedown');
  var g = d3.select('g.node_mousedown');
  if (g.empty()) {
    console.log('g.node_mousedown not found, adding node_mousedown');
    g = buildGraphElement
      .append('g')
      .attr('class', 'node_mousedown')
      .attr('id', 'zoom');
    // svg.on('mousedown', (e, d) => {
    //   // stop propagation on buttons and ctrl+click
    //   if (e.button || e.ctrlKey) {
    //     e.stopImmediatePropagation();
    //   }
    // });
  }

  buildGraphElement
    .attr('height', h * 2) // make dynamic depending on the number of nodes or depth?
    .attr('width', w * 2)
    .style('outline', '1px solid var(--color-bg-light)')
    .style('background', 'var(--color-bg-dark)');
  // .style('margin-right', '1rem');

  // this centers the graph in the viewbox, or something like that
  buildGraphElement = g;

  buildGraphElement.html(content);

  buildGraphElement.selectAll('title').remove();
  buildGraphElement.selectAll('*').attr('xlink:title', null);

  if (buildGraphElement.node() == null) {
    console.log('unable to get bounding box, build graph node is null');
    return;
  }
  let svg = buildGraphElement.select('svg');

  // svg.style('outline', '1px solid green');
  svg.style('overflow', 'visible');
  svg.style('border-radius', '4px');

  var bbox = buildGraphElement.node().getBBox();
  const VIEWBOX_PADDING = { x1: 0, x2: 0, y1: 40, y2: 40 };
  var parent = d3.select(buildGraphElement.node().parentNode);
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

  console.log('removing outline from all .stage-node a');
  buildGraphElement.selectAll('.stage-node a').filter(function () {
    let a = d3.select(this);
    a.attr('style', 'outline: none');
    a.on('mouseover', e => {
      a.style('outline', '1px solid white');
    });
    a.on('mouseout', e => {
      a.style('outline', 'none');
    });
    return ''; // used by filter (?)
  });

  console.log('processing all .stage-edge');
  buildGraphElement.selectAll('.stage-edge').filter(function () {
    let a = d3.select(this);
    a.attr('style', 'outline: none');
    a.on('mouseover', e => {
      a.select('path').style('stroke', 'green');
    });
    a.on('mouseout', e => {
      a.select('path').style('stroke', 'white');
    });
    return ''; // used by filter (?)
  });

  console.log('processing all .stage-node a');
  buildGraphElement.selectAll('.stage-node a').filter(function () {
    console.log('checking .stage-node a');
    var href = d3.select(this).attr('xlink:href');
    if (href !== null) {
      d3.select(this).on('click', function (e) {
        e.preventDefault();
        console.log('handling node onclick href event');
        // @ts-ignore
        setTimeout(
          () =>
            app.ports.onGraphInteraction.send({
              event_type: 'href',
              href: href,
            }),
          0,
        );
      });
    }
    return ''; // used by filter (?)
  });

  console.log('processing all .stage-node');
  let i = 0;
  buildGraphElement.selectAll('.stage-node').filter(function () {
    console.log('processing single .stage-node ' + i++);

    // how do i only select
    // var inner = d3.select(this).node().innerHTML;

    // used to embed step status
    // if (inner !== undefined && inner.startsWith('xyz123-')) {
    if (1) {
      // var status = inner.replace('xyz123-', '');
      var og = d3.select(this).select('a');

      var ogX = og.select('text').attr('x');
      var ogY = og.select('text').attr('y');

      console.log('grabbing stage node parent');
      var node = og.node();

      const parent = d3.select(node.parentNode);
      // og.remove();

      console.log('need node bounding box size');
      console.log(parent.node().getBBox());
      let box = parent.node().getBBox();
      // parent.append("path")
      // // .attr("d", d3.svg.symbol()
      // //     .size(function(d) { return d.size; })
      // //     .type(function(d) { return d.type; }))
      // .style("fill", "steelblue")
      // .style("stroke", "black")
      // .style("stroke-width", "1.5px");

      console.log('appending image to .stage-node parent');

      parent
        .append('image')
        .attr('xlink:href', '/images/vela_' + 'success' + '.png')
        .attr('x', box.x)
        .attr('y', box.y)
        .attr('width', 12)
        .attr('height', 12)
        .style('stroke', 'red')
        .style('fill', 'red')
        .style('stroke-width', '1px')
        .style('cursor', 'pointer')
        .on('click', function (e) {
          e.preventDefault();
          // this might not be needed
          console.log('new onclick 2');
          // @ts-ignore
          // setTimeout(() => app.ports.onGraphInteraction.send({ event_type: "href", href: 'href' }), 0);
        });

      // og.remove();
    }

    return ''; // filter by single attribute
  });
}
