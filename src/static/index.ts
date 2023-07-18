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

import { Graphviz } from '@hpcc-js/wasm';

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

app.ports.renderBuildGraph.subscribe(function (dot) {
  const graphviz = Graphviz.load().then(res => {
    var content = res.layout(dot, 'svg', 'dot');
    drawGraph(content);
  });
});

function drawGraph(content) {
  // force d3 exports to resolve, required or we receive errors when running within a container
  // this is why we love javascript
  var _ = d3;

  // define DOM selectors for DOT-generated elements
  var graphSelectors = {
    root: '.elm-build-graph-root',
    node: '.elm-build-graph-node',
    edge: '.elm-build-graph-edge',
  };

  var buildGraphElement = drawBaseGraph(graphSelectors.root, content);

  // check that a valid graph was rendered
  if (buildGraphElement.node() == null) {
    console.log('unable to continue drawing graph, root element is invalid');
    console.log(buildGraphElement);
    return;
  }

  drawViewbox(buildGraphElement);

  // apply onclick to base node links prior to adding/removing elements
  applyNodesOnClick(buildGraphElement, graphSelectors.node);

  var edges = drawEdges(buildGraphElement, graphSelectors.edge);

  drawNodes(buildGraphElement, graphSelectors.node, edges);
}

function drawBaseGraph(selector, content) {
  // grab the build graph root element
  var buildGraphElement = d3.select(selector);

  // enable d3 zoom and pan functionality
  buildGraphElement.call(
    d3.zoom().scaleExtent([0.1, Infinity]).on('zoom', zoomed),
  );

  // define d3 zoom function
  function zoomed(event) {
    var g = d3.select(selector + ' g');
    g.attr('transform', event.transform);
  }

  // apply mousedown zoom effects
  var g = d3.select('g.node_mousedown');
  if (g.empty()) {
    g = buildGraphElement
      .append('g')
      .classed('node_mousedown', true)
      .attr('id', 'zoom');
  }

  let height = 800;
  buildGraphElement
    .attr('height', height) // make dynamic depending on the number of nodes or depth?
    .attr('width', '100%');

  // this centers the graph in the viewbox, or something like that
  buildGraphElement = g;

  // draw content into html
  buildGraphElement.html(content);

  return buildGraphElement;
}

function drawViewbox(buildGraphElement) {
  var graphBBox = buildGraphElement.node().getBBox();

  // apply viewbox properties to the root element's parent
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
}

function drawNodes(buildGraphElement, selector, edges) {
  buildGraphElement.selectAll(selector).filter(function () {
    let stageNode = d3.select(this);
    var nodeBBox = stageNode.node().getBBox();

    // apply an outline using rect, since nodes are rect and this will allow for animation
    var outline = stageNode.append('rect');
    outline
      .attr('x', nodeBBox.x)
      .attr('y', nodeBBox.y)
      .attr('width', nodeBBox.width)
      .attr('height', nodeBBox.height);

    var stageInfo = stageNode.attr('id').replace('#', '').split(',');

    // todo: safety-check
    var stageStatus = stageInfo[1];

    // restore base class and build modifiers
    outline.attr('class', 'd3-build-graph-node-outline-rect');

    var restoreNodeClass = o => {
      o.classed('-pending', true);
    };

    if (stageStatus === 'failure') {
      restoreNodeClass = o => {
        o.classed('-failure', true);
      };
    }

    if (stageStatus === 'success') {
      restoreNodeClass = o => {
        o.classed('-success', true);
      };
    }

    if (stageStatus === 'running') {
      restoreNodeClass = o => {
        o.classed('-running', true);
      };
    }

    if (stageStatus === 'killed') {
      restoreNodeClass = o => {
        o.classed('-killed', true);
      };
    }

    restoreNodeClass(outline);

    stageNode.on('mouseover', e => {
      outline.classed('-hover', true);

      // take this stage
      // filter out all the edges that arent source/dest of each edge
      edges.filter(function (edgeInfo) {
        if (
          // todo: safety-check
          stageInfo[0] === edgeInfo.source ||
          stageInfo[0] === edgeInfo.destination
        ) {
          edgeInfo.target.classed('-hover', true);
        }
      });
    });

    stageNode.on('mouseout', e => {
      // remove node outline styling
      outline.classed('-hover', false);

      // restore node styling
      restoreNodeClass(outline);

      // restore edge styling
      edges.filter(function (edgeInfo) {
        // modify styling only on related edges
        if (
          // todo: safety-check
          stageInfo[0] === edgeInfo.source ||
          stageInfo[0] === edgeInfo.destination
        ) {
          var status = edgeInfo.status;

          edgeInfo.target.classed('-hover', false);

          var restoreEdgeClass = o => {
            o.classed('-pending', true);
          };

          if (status === 'running') {
            restoreEdgeClass = o => {
              o.classed('-running', true);
            };
          }

          if (status === 'success') {
            restoreEdgeClass = o => {
              o.classed('-success', true);
            };
          }

          if (status === 'failure') {
            restoreEdgeClass = o => {
              o.classed('-failure', true);
            };
          }

          restoreEdgeClass(edgeInfo.target);
        }
      });
    });

    stageNode.selectAll('a').filter(function () {
      var step = d3.select(this);
      if (step.attr('xlink:href').includes('#step')) {
        // restore base class and build modifiers
        step.attr('class', 'd3-build-graph-node-step-a');

        step.on('mouseover', e => {
          step.classed('-hover', true);
        });
        step.on('mouseout', e => {
          step.classed('-hover', false);
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

        // todo: static/*.png seems like a bad way to do icon images
        parent
          .append('image')
          .attr('xlink:href', '/images/vela_' + status + '.png')
          .attr('x', nodeBox.x - 6)
          .attr('y', nodeBox.y)
          .attr('width', 16)
          .attr('height', 16);

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

// applyNodesOnClick takes root graph element, selects node links and applies onclick functionality
function applyNodesOnClick(buildGraphElement, selector) {
  // process and return all 'linked' stage nodes
  return buildGraphElement.selectAll(selector + ' a').filter(function () {
    // todo: figure out .each
    // add onclick to nodes with valid href attributes
    var href = d3.select(this).attr('xlink:href');
    if (href !== null) {
      d3.select(this).on('click', function (e) {
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
}

function drawEdges(buildGraphElement, selector) {
  // collect edge information to use in other d3 interactivity
  var edges = [];

  buildGraphElement.selectAll(selector).filter(function () {
    let a = d3.select(this);
    var edgeInfo = a.attr('id').replace('#', '').split(',');

    // todo: safety-check
    var status = edgeInfo[2];

    var p = a.select('path');

    edges.push({
      target: p,
      source: edgeInfo[0], // todo: safety-check
      destination: edgeInfo[1], // todo: safety-check
      status: status,
    });

    // restore base class and build modifiers
    p.attr('class', 'd3-build-graph-edge-path');

    var restoreEdgeClass = o => {
      o.classed('-pending', true);
    };

    if (status === 'running') {
      restoreEdgeClass = o => {
        o.classed('-running', true);
      };
    }

    if (status === 'success') {
      restoreEdgeClass = o => {
        o.classed('-success', true);
      };
    }

    if (status === 'failure') {
      restoreEdgeClass = o => {
        o.classed('-failure', true);
      };
    }

    restoreEdgeClass(p);

    a.on('mouseover', e => {
      p.classed('-hover', true);
    });

    a.on('mouseout', e => {
      restoreEdgeClass(p);
      p.classed('-hover', false);
    });

    return ''; // used by filter (?)
  });

  return edges;
}
