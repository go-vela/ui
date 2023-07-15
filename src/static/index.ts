// Copyright (c) 2022 Target Brands, Inc. All rights reserved.
//
// Use of this source code is governed by the LICENSE file in this repository.

// todo: remove
// @ts-nocheck

// import types
import * as ClipboardJS from 'clipboard';
import { Console } from 'console';
import * as d3 from 'd3';

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

        console.log('preparing to draw content');

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

  // grab the build graph root element
  var buildGraphElement = d3.select('.build-graph');

  // enable d3 zoom and pan functionality
  buildGraphElement.call(
    d3.zoom().scaleExtent([0.1, Infinity]).on('zoom', zoomed),
  );

  // define d3 zoom function
  function zoomed(event) {
    var g = d3.select('.build-graph g');
    g.attr('transform', event.transform);
  }

  // apply mousedown zoom effects
  var g = d3.select('g.node_mousedown');
  if (g.empty()) {
    g = buildGraphElement
      .append('g')
      .attr('class', 'node_mousedown')
      .attr('id', 'zoom');
  }

  let height = 800;
  buildGraphElement
    .attr('height', height) // make dynamic depending on the number of nodes or depth?
    .attr('width', '100%')
    .style('outline', '1px solid var(--color-bg-light)')
    .style('background', 'var(--color-bg-dark)');

  // this centers the graph in the viewbox, or something like that
  buildGraphElement = g;

  // draw content into html
  buildGraphElement.html(content);

  // check that a valid graph was rendered
  if (buildGraphElement.node() == null) {
    console.log('unable to get bounding box, build graph node is null');
    return;
  }

  // set the base graph padding
  var graphBBox = buildGraphElement.node().getBBox();
  const VIEWBOX_PADDING = { x1: 0, x2: 0, y1: 40, y2: 40 };
  var graphParent = d3.select(buildGraphElement.node().parentNode);
  graphParent.attr(
    'viewBox',
    '' +
      (graphBBox.x - VIEWBOX_PADDING.x1) +
      ' ' +
      (graphBBox.y - VIEWBOX_PADDING.y1) +
      ' ' +
      (graphBBox.width + VIEWBOX_PADDING.x2) +
      ' ' +
      (graphBBox.height + VIEWBOX_PADDING.y2),
  );

  // process all stage nodes
  buildGraphElement.selectAll('.stage-node a').filter(function () {
    // add onclick to nodes with valid href attributes
    var href = d3.select(this).attr('xlink:href');
    if (href !== null) {
      d3.select(this).on('click', function (e) {
        console.log('handle onclick STAGE NODE');

        e.preventDefault();

        var nodeA = d3.select(this);

        // extract identifier from href
        // todo: make this use title
        var data = nodeA.attr('xlink:href');
        nodeA.attr('xlink:href', null);
        let id = data.replace('#', '');

        setTimeout(
          () =>
            app.ports.onGraphInteraction.send({
              event_type: 'node_click',
              node_id: id,
            }),
          0,
        );
      });
    }
    return '';
  });

  var edges = [];
  buildGraphElement.selectAll('.stage-edge').filter(function () {
    let a = d3.select(this);
    var edgeInfo = a.attr('id').replace('#', '').split(',');

    var status = edgeInfo[2];

    var p = a.select('path');

    edges.push({
      target: p,
      source: edgeInfo[0],
      destination: edgeInfo[1],
      status: status,
    });

    p.style('animation', 'none');
    var restoreEdgeStyle = o => {
      o.style('stroke', 'var(--color-gray)');
      o.style('stroke-dasharray', '10, 4');
    };

    if (status === 'running') {
      restoreEdgeStyle = o => {
        o.style('stroke', 'var(--color-yellow)');
        o.style('stroke-dasharray', '10, 4');
        o.style('animation', 'dash 25s linear');
      };
    }

    if (status === 'success') {
      restoreEdgeStyle = o => {
        o.style('stroke', 'var(--color-gray)');
        o.style('stroke-dasharray', null);
      };
    }

    if (status === 'failure') {
      restoreEdgeStyle = o => {
        o.style('stroke', 'var(--color-gray)');
        o.style('stroke-dasharray', null);
      };
    }

    restoreEdgeStyle(p);

    a.on('mouseover', e => {
      p.style('stroke', 'var(--color-primary)');
    });

    a.on('mouseout', e => {
      restoreEdgeStyle(p);
    });

    return ''; // used by filter (?)
  });

  buildGraphElement.selectAll('.stage-node').filter(function () {
    let stageNode = d3.select(this);
    var nodeBBox = stageNode.node().getBBox();

    // apply an outline using rect, since nodes are rect and this will allow for animation
    var outline = stageNode.append('rect');
    outline
      .attr('x', nodeBBox.x)
      .attr('y', nodeBBox.y)
      .attr('width', nodeBBox.width)
      .attr('height', nodeBBox.height)
      .style('fill', 'none');

    var stageInfo = stageNode.attr('id').replace('#', '').split(',');

    var stageStatus = stageInfo[1];

    var restoreNodeStyle = o => {};
    if (stageStatus === 'failure') {
      restoreNodeStyle = o => {
        o.style('stroke', 'var(--color-red)')
          .style('stroke-width', '1.8')
          .style('stroke-dasharray', null)
          .style('animation', 'none');
      };
    }

    if (stageStatus === 'success') {
      restoreNodeStyle = o => {
        o.style('stroke', 'var(--color-green)')
          .style('stroke-width', '1.8')
          .style('stroke-dasharray', null)
          .style('animation', 'none');
      };
    }

    if (stageStatus === 'running') {
      restoreNodeStyle = o => {
        o.style('stroke', 'var(--color-yellow)')
          .style('stroke-width', '1.8')
          .style('stroke-dasharray', '10')
          .style('animation', 'dash 25s linear');
      };
    }

    if (stageStatus === 'killed') {
      restoreNodeStyle = o => {
        o.style('stroke', 'var(--color-lavender)')
          .style('stroke-width', '1.8')
          .style('stroke-dasharray', null)
          .style('animation', 'none');
      };
    }

    restoreNodeStyle(outline);

    stageNode.on('mouseover', e => {
      outline
        .style('stroke', 'var(--color-primary)')
        .style('stroke-width', '1.8');

      // take this stage
      // filter out all the edges that arent source/dest of each edge
      edges.filter(function (edgeInfo) {
        if (
          stageInfo[0] === edgeInfo.source ||
          stageInfo[0] === edgeInfo.destination
        ) {
          edgeInfo.target.style('stroke', 'var(--color-primary)');
        }
      });
    });

    stageNode.on('mouseout', e => {
      outline.style('stroke', 'none');
      restoreNodeStyle(outline);

      edges.filter(function (edgeInfo) {
        if (
          stageInfo[0] === edgeInfo.source ||
          stageInfo[0] === edgeInfo.destination
        ) {
          var status = edgeInfo.status;

          var restoreEdgeStyle = o => {
            o.style('stroke', 'var(--color-gray)');
            o.style('stroke-dasharray', '10, 4');
          };

          if (status === 'running') {
            restoreEdgeStyle = o => {
              o.style('stroke', 'var(--color-yellow)');
              o.style('stroke-dasharray', '10, 4');
              o.style('animation', 'dash 25s linear');
            };
          }

          if (status === 'success') {
            restoreEdgeStyle = o => {
              o.style('stroke', 'var(--color-gray)');
              o.style('stroke-dasharray', null);
            };
          }

          if (status === 'failure') {
            restoreEdgeStyle = o => {
              o.style('stroke', 'var(--color-gray)');
              o.style('stroke-dasharray', null);
            };
          }

          restoreEdgeStyle(edgeInfo.target);
        }
      });
    });

    stageNode.selectAll('a').filter(function () {
      var step = d3.select(this);
      if (step.attr('xlink:href').includes('#step')) {
        step.attr('style', 'outline: none');
        step.on('mouseover', e => {
          step.style('outline', '1px solid var(--color-primary)');
          step.style('outline-style', 'dashed');
        });
        step.on('mouseout', e => {
          step.style('outline', 'none');
        });
      }
    });

    stageNode.selectAll('#a_node-cell').filter(function () {
      var cell = d3.select(this);
      var cellNode = cell.select('text').node();
      if (cellNode) {
        let parent = d3.select(cellNode.parentNode);
        let nodeBox = cellNode.getBBox();

        // extract href to dispatch to Elm
        var href = parent.attr('xlink:href');

        // remove actual href attribute
        parent.attr('xlink:href', null);

        var stepInfo = parent.attr('xlink:title').split(',');

        // todo: safety check
        var status = stepInfo[2];

        parent
          .append('image')
          .attr('xlink:href', '/images/vela_' + status + '.png')
          .attr('x', nodeBox.x - 6)
          .attr('y', nodeBox.y)
          .attr('width', 16)
          .attr('height', 16)
          .style('stroke', 'red')
          .style('fill', 'red')
          .style('stroke-width', '1px')
          .style('cursor', 'pointer');

        parent.on('click', function (e) {
          e.preventDefault();

          // prevents multiple link events getting fired from a single click
          e.stopImmediatePropagation();

          setTimeout(
            () =>
              app.ports.onGraphInteraction.send({
                event_type: 'href',
                href: href,
                step_id: '',
              }),
            0,
          );
        });
      }
    });

    return ''; // used by filter (?)
  });
}
