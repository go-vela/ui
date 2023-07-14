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
        console.log(drawContent);

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
  }

  buildGraphElement
    .attr('height', h * 2) // make dynamic depending on the number of nodes or depth?
    .attr('width', '100%')
    .style('outline', '1px solid var(--color-bg-light)')
    .style('background', 'var(--color-bg-dark)');
  // .style('margin-right', '1rem');

  // this centers the graph in the viewbox, or something like that
  buildGraphElement = g;

  buildGraphElement.html(content);

  // buildGraphElement.selectAll('title').remove();
  // buildGraphElement.selectAll('*').attr('xlink:title', null);

  if (buildGraphElement.node() == null) {
    console.log('unable to get bounding box, build graph node is null');
    return;
  }
  let svg = buildGraphElement.select('svg');

  // svg.style('outline', '1px solid green');
  svg.style('overflow', 'visible');

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
  buildGraphElement.selectAll('.stage-node').filter(function () {
    let stageNode = d3.select(this);

    var stageStatus = stageNode.attr('id').replace('#', '');

    var bbox = stageNode.node().getBBox();
    var outline = stageNode.append('rect');
    outline
      .attr('x', bbox.x)
      .attr('y', bbox.y)
      .attr('width', bbox.width)
      .attr('height', bbox.height)
      .attr('class', 'stage-node-outline')
      .style('fill', 'none');

    var outlineColor = 'gray';
    var outlineStyle = 'solid';
    var restoreStyle = o => {};

    if (stageStatus === 'failure') {
      outlineColor = 'var(--color-red-dark)';

      restoreStyle = o => {
        o.style('stroke', outlineColor)
          .style('stroke-width', '1')
          .style('stroke-dasharray', null)
          .style('animation', 'none');
      };
    }
    if (stageStatus === 'success') {
      outlineColor = 'var(--color-green)';

      restoreStyle = o => {
        o.style('stroke', outlineColor)
          .style('stroke-width', '1')
          .style('stroke-dasharray', null)
          .style('animation', 'none');
      };
    }

    if (stageStatus === 'running') {
      outlineColor = 'var(--color-yellow)';

      outlineStyle = 'dashed';

      restoreStyle = o => {
        o.style('stroke', outlineColor)
          .style('stroke-width', '1.8')
          .style('stroke-dasharray', '10')
          .style('animation', 'dash 25s linear');
      };
    }

    if (stageStatus === 'killed') {
      outlineColor = 'var(--color-lavender)';

      restoreStyle = o => {
        o.style('stroke', outlineColor)
          .style('stroke-width', '1')
          .style('stroke-dasharray', null)
          .style('animation', 'none');
      };
    }

    restoreStyle(outline);

    stageNode.on('mouseover', e => {
      outline
        .style('stroke', 'var(--color-primary)')
        .style('stroke-width', '1.8')
        .style('stroke-dasharray', null)
        .style('animation', 'none');
      // .style('animation', 'dash 25s linear')
    });
    stageNode.on('mouseout', e => {
      // outline.style('outline', '1px solid ' + outlineColor);
      // stageNode.style('outline-style', 'dashed');
      outline.style('stroke', 'none');
      restoreStyle(outline);
    });

    var steps = stageNode.selectAll('a').filter(function () {
      var step = d3.select(this);
      if (step.attr('xlink:href').includes('#step')) {
        console.log('%c found link', 'color: red');
        step.attr('style', 'outline: none');
        step.on('mouseover', e => {
          step.style('outline', '1px solid var(--color-primary)');
          step.style('outline-style', 'dashed');
        });
        step.on('mouseout', e => {
          step.style('outline', 'none');
        });

        // NOT NEEDED, taken care of by the IMAGE parent onclick

        // step.on('click', function (e) {
        //   e.preventDefault();

        //   // prevents multiple link events getting fired from a single click
        //   e.stopImmediatePropagation();

        //   // this might not be needed
        //   console.log('handle onclick STEP');

        //   // todo: somehow pass back step ID on click

        //   console.log("vader: " + step.attr('xlink:title'));

        //   // split id,name,status
        //   return;

        //   // @ts-ignore
        //   setTimeout(() => app.ports.onGraphInteraction.send({ event_type: "href", href: 'href', step_id: "pls" }), 0);
        // });
      }
    });

    return ''; // used by filter (?)
  });

  console.log('processing all .stage-edge');

  buildGraphElement.selectAll('.stage-edge').filter(function () {
    let a = d3.select(this);
    a.attr('style', 'outline: none');
    a.on('mouseover', e => {
      var p = a.select('path');

      p.style('stroke', 'var(--color-primary)');
      p.attr('stoke-width', '3');

      var xPos = p.attr('x');
      var wid = p.attr('width');

      p.attr('x', xPos - 10).attr('width', wid + 20);
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
        console.log('handle onclick STAGE NODE');

        var huh = d3.select(this);
        e.preventDefault();
        var data = huh.attr('xlink:href');

        huh.attr('xlink:href', null);

        // @ts-ignore
        setTimeout(
          () =>
            app.ports.onGraphInteraction.send({
              event_type: 'node_click',
              // href: href,
              node_id: data.replace('#', ''),
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

    var dd = d3.select(this);

    dd.selectAll('#a_node-cell').filter(function () {
      console.log('processing #step-icon');
      var icon = d3.select(this);
      var node = icon.select('text').node();
      // icon.style('outline', '1px solid pink');
      if (node) {
        console.log('grabbing parent node');
        var parentNode = node.parentNode;

        console.log('using parent node to select');
        const parent = d3.select(node.parentNode);
        // og.remove();

        console.log('need node bounding box size');
        console.log(parent.node().getBBox());
        let parentBox = parent.node().getBBox();
        let nodeBox = node.getBBox();
        // parent.append("path")
        // // .attr("d", d3.svg.symbol()
        // //     .size(function(d) { return d.size; })
        // //     .type(function(d) { return d.type; }))
        // .style("fill", "steelblue")
        // .style("stroke", "black")
        // .style("stroke-width", "1.5px");

        console.log('appending image to .stage-node parent');
        console.log(parent);
        var ogLink = parent.attr('xlink:href');

        // parent.attr('xlink:href', 'https://google.com');
        parent.attr('xlink:href', null);

        console.log('step info: ');
        var stepInfo = parent.attr('xlink:title').split(',');
        var status = stepInfo[2];

        console.log(parent.attr('xlink:title'));

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

          // this might not be needed
          console.log('handle onclick STEP');
          console.log('og link ' + ogLink);
          // todo: somehow pass back step ID on click

          // return;
          // @ts-ignore
          setTimeout(
            () =>
              app.ports.onGraphInteraction.send({
                event_type: 'href',
                href: ogLink,
                step_id: '',
              }),
            0,
          );
        });

        // node.remove();
      }
    });

    return ''; // filter by single attribute
  });
}
