// Copyright (c) 2022 Target Brands, Inc. All rights reserved.
//
// Use of this source code is governed by the LICENSE file in this repository.

import * as d3 from 'd3';

export function drawGraph(opts, content) {
  // force d3 exports to resolve, required or we receive errors when running within a container
  // this is why we love javascript
  var _ = d3;

  // define DOM selectors for DOT-generated elements
  var graphSelectors = {
    root: '.elm-build-graph-root',
    node: '.elm-build-graph-node',
    edge: '.elm-build-graph-edge',
  };

  var buildGraphElement = drawBaseGraphWithZoom(
    opts,
    graphSelectors.root,
    content,
  );

  // check that a valid graph was rendered
  if (buildGraphElement === null || buildGraphElement.node() === null) {
    return;
  }

  drawViewbox(opts, buildGraphElement);

  applyOnClickToNodes(opts, buildGraphElement, graphSelectors.node);

  var edges = drawEdges(opts, buildGraphElement, graphSelectors.edge);

  drawNodes(opts, buildGraphElement, graphSelectors.node, edges);
}

function drawBaseGraphWithZoom(opts, selector, content) {
  // grab the build graph root element
  var buildGraphElement = d3.select(selector);

  var zoom = d3.zoom().scaleExtent([0.1, Infinity]).on('zoom', handleZoom);

  // define d3 zoom function
  function handleZoom(event) {
    if (isNaN(event.transform.k)) {
      event.transform.k = 1;
    }
    if (isNaN(event.transform.x)) {
      event.transform.x = 0;
    }
    if (isNaN(event.transform.y)) {
      event.transform.y = 0;
    }
    var zoomG = d3.select(selector + ' g');
    zoomG.attr('transform', event.transform);
  }

  function resetZoomAndCenter(opts, zoom) {
    var zoomG = d3.select(selector);

    // reset zoom scale to 1
    zoomG.call(zoom.scaleTo, 1);

    // the name of this variable is confusing
    var zoomGg = d3.select(selector);
    var zoomBBox = zoomGg.node().getBBox();
    var w = zoomBBox.width;
    var h = zoomBBox.height;
    zoomGg
      .transition() // required to 'chain' these two instant animations together
      .duration(0)
      .call(zoom.translateTo, w * 0.5, h * 0.5);
  }

  // enable d3 zoom and pan functionality
  buildGraphElement.call(zoom);

  var actionResetPan = d3.select('#action-center');

  // apply zoom onclick
  actionResetPan.on('click', e => {
    e.preventDefault();
    resetZoomAndCenter(opts, zoom);
  });

  // apply mousedown zoom effects
  var g = d3.select('g.node_mousedown');
  if (g.empty()) {
    var zoomG = d3.select(selector);
    if (!zoomG.node()) {
      return null;
    }

    var zoomBBox = zoomG.node().getBBox();
    var w = zoomBBox.width;
    var h = zoomBBox.height;
    g = buildGraphElement.append('g');
    g.classed('node_mousedown', true).attr('id', 'zoom');
  }

  // apply backdrop onclick
  buildGraphElement.on('click', e => {
    e.preventDefault();
    setTimeout(() => {
      opts.onGraphInteraction.send({
        event_type: 'backdrop_click',
      });
    }, 0);
  });

  // this centers the graph in the viewbox, or something like that
  buildGraphElement = g;

  // draw content into html
  buildGraphElement.html(content);

  // recenter on draw, when necessary
  if (!opts.isRefreshDraw) {
    resetZoomAndCenter(opts, zoom);
  }

  if (opts.centerOnDraw) {
    resetZoomAndCenter(opts, zoom);
  }

  return buildGraphElement;
}

function drawViewbox(opts, buildGraphElement) {
  var graphBBox = buildGraphElement.node().getBBox();

  // apply viewbox properties to the root element's parent
  // provide x padding for the legend
  const padding = { x1: 0, x2: 500, y1: 0, y2: 100 };

  var graphParent = d3.select(buildGraphElement.node().parentNode);
  graphParent.attr(
    'viewBox',
    '' +
      (graphBBox.x - padding.x1) +
      ' ' +
      (graphBBox.y - padding.y1) +
      ' ' +
      (graphBBox.width + padding.x2) +
      ' ' +
      (graphBBox.height + padding.y2),
  );
}

function drawNodes(opts, buildGraphElement, nodeSelector, edges) {
  buildGraphElement.selectAll(nodeSelector).filter(function () {
    let node = d3.select(this);
    node.select('polygon').classed('d3-build-graph-node', true);

    // apply an outline using rect, since nodes are rect and this will allow for animation
    var nodeBBox = node.node().getBBox();
    var outline = node.append('rect');
    outline
      .attr('x', nodeBBox.x)
      .attr('y', nodeBBox.y)
      .attr('width', nodeBBox.width)
      .attr('height', nodeBBox.height);

    // extract information embedded in the element id for advanced styling
    var data = getNodeDataFromID(node);

    // restore base class and build modifiers
    outline.classed('d3-build-graph-node-outline-rect', true);
    outline.classed('d3-build-graph-node-outline-' + data.id, true);
    outline.classed('-' + data.status, true);

    // apply click-focus styling
    if (data.focused && data.focused === 'true') {
      outline.classed('-focus', true);
    }

    node.on('mouseover', e => {
      // apply outline styling
      outline.classed('-hover', true);

      // apply styling to edges relevant to this node
      edges.filter(edge => {
        if (data.id === edge.source || data.id === edge.destination) {
          edge.target.classed('-hover', true);
        }
      });
    });

    node.on('mouseout', e => {
      // remove outline styling
      outline.classed('-hover', false);

      // remove styling from edges relevant to this node
      edges.filter(edge => {
        if (data.id === edge.source || data.id === edge.destination) {
          edge.target.classed('-hover', false);
          edge.target.classed('-' + edge.status, true);
        }
      });
    });

    var stepIconSize = 16;

    node.selectAll('a').filter(function () {
      var step = d3.select(this);
      if (step.attr('xlink:href').includes('#step:')) {
        // restore base class and build modifiers
        step.classed('d3-build-graph-node-step-a', true);

        // apply an outline using rect, since nodes are rect and this will allow for animation
        var underline = step.append('rect');
        var aBBox = step.node().getBBox();
        underline
          .attr('x', aBBox.x + stepIconSize)
          .attr('y', aBBox.y + aBBox.height)
          .attr('width', aBBox.width - stepIconSize);

        // restore base class and build modifiers
        underline.classed('d3-build-graph-node-step-a-underline', true);

        // apply step table row hover styles
        step.on('mouseover', e => {
          step.classed('-hover', true);
          underline.classed('-hover', true);

          // draw underline
          underline.attr('height', 1);
        });
        step.on('mouseout', e => {
          step.classed('-hover', false);
          underline.classed('-hover', false);

          // clear underline
          underline.attr('height', 0);
        });
      }
    });

    // track step number for applying styles
    var i = 0;

    // draw node cells (steps)
    node.selectAll('#a_node-cell').filter(function () {
      var cell = d3.select(this).select('text').node();
      if (cell) {
        let cellParent = d3.select(cell.parentNode);

        var step = getStepDataFromTitle(cellParent);

        let cellBBox = cell.getBBox();

        const iconPadding = { w: 2, h: 2, x: 3, y: 1 };

        cellParent
          .append('rect')
          .classed('d3-build-graph-step-icon', true)
          .classed('-' + step.status, true)
          .attr('width', stepIconSize + iconPadding.w)
          .attr('height', stepIconSize + iconPadding.h)
          .attr('x', cellBBox.x - iconPadding.x)
          .attr('y', cellBBox.y - iconPadding.y)
          .attr('rx', '1')
          .attr('ry', '1');

        var stepIcon = cellParent.append('svg');
        stepIcon
          .classed('-' + step.status, true)
          .attr('viewBox', '0 0 28 28')
          .attr('x', cellBBox.x - iconPadding.x)
          .attr('y', cellBBox.y - iconPadding.y)
          .attr('width', stepIconSize + iconPadding.w)
          .attr('height', stepIconSize + iconPadding.h);

        // build the icon svg based on step status

        if (step.status === 'pending') {
          stepIcon
            .append('circle')
            .attr('cx', '14')
            .attr('cy', '14')
            .attr('r', '2');
        }

        if (step.status === 'running') {
          stepIcon.append('path').attr('d', 'M14 7v7.5l5 2.5');
        }

        if (step.status === 'success') {
          stepIcon.append('path').attr('d', 'M6 15.9227L10.1026 20 22 7');
        }

        if (step.status === 'failure') {
          stepIcon.append('path').attr('d', 'M8 8l12 12M20 8L8 20');
        }

        if (step.status === 'canceled') {
          stepIcon.append('path').attr('d', 'M8 8l12 12M20 8L8 20');
        }

        if (step.status === 'killed') {
          stepIcon
            .append('circle')
            .attr('cx', '9')
            .attr('cy', '14')
            .attr('r', '2');
          stepIcon
            .append('circle')
            .attr('cx', '19')
            .attr('cy', '14')
            .attr('r', '2');
        }

        if (step.status === 'skipped') {
          stepIcon
            .append('circle')
            .attr('cx', '9')
            .attr('cy', '14')
            .attr('r', '2');
          stepIcon
            .append('circle')
            .attr('cx', '19')
            .attr('cy', '14')
            .attr('r', '2');
        }

        if (step.status === 'error') {
          stepIcon.append('path').attr('d', 'M8 8l12 12M20 8L8 20');
        }

        // apply step connector to every step after the first
        if (i > 0) {
          const connectorPadding = { x: 5.5, y: -6 };
          const connectorSize = { w: 1, h: 4 };
          var connector = cellParent.append('rect');
          connector
            .classed('d3-build-graph-step-connector', true)
            .attr('x', cellBBox.x + connectorPadding.x)
            .attr('y', cellBBox.y + connectorPadding.y)
            .attr('width', connectorSize.w)
            .attr('height', connectorSize.h);
        }
        i++;

        // extract and remove the href to dispatch link clicks to Elm
        var href = cellParent.attr('xlink:href');
        cellParent.attr('xlink:href', null);
        cellParent.on('click', e => {
          e.preventDefault();
          // prevents multiple link events getting fired from a single click
          e.stopImmediatePropagation();
          setTimeout(() => {
            opts.onGraphInteraction.send({
              event_type: 'href',
              href: href,
              step_id: '',
            });
          }, 0);
        });
      }
    });
  });
}

function drawEdges(opts, buildGraphElement, edgeSelector) {
  // collect edge information to use in other interactivity
  var edges: any[] = [];

  buildGraphElement.selectAll(edgeSelector).filter(function () {
    d3.select(this).select('ellipse').classed('d3-build-graph-edge-tip', true);
    let a = d3.select(this);
    var p = a.select('path');

    // extract information embedded in the element id for advanced styling
    var data = getEdgeDataFromID(a);
    var edge = {
      target: p,
      ...data,
    };
    edges.push(edge);

    // restore base class and build modifiers
    p.classed('d3-build-graph-edge-path', true)
      .classed(
        'd3-build-graph-edge-path-' + data.source + '-' + data.destination,
        true,
      )
      .classed('-' + data.status, true);

    if (data.focused && data.focused === 'true') {
      p.classed('-focus', true);
    }
  });

  return edges;
}

// applyOnClickToNodes takes root graph element, selects node links and applies onclick functionality
function applyOnClickToNodes(opts, buildGraphElement, nodeSelector) {
  // process and return all 'linked' stage nodes
  return buildGraphElement.selectAll(nodeSelector + ' a').filter(function () {
    // add onclick to nodes with valid href attributes
    var a = d3.select(this);
    var href = a.attr('xlink:href');
    a.classed('d3-build-graph-node-a', true);

    if (href !== null) {
      d3.select(this).on('click', e => {
        e.preventDefault();
        e.stopImmediatePropagation();

        var nodeA = d3.select(this);
        nodeA.attr('xlink:href', null);

        var stageInfo = nodeA.attr('xlink:title').replace('#', '').split(',');
        var stageID = '-1';
        if (stageInfo && stageInfo.length == 4) {
          stageID = stageInfo[0];
        }

        // dispatch Elm interop
        setTimeout(() => {
          opts.onGraphInteraction.send({
            event_type: 'node_click',
            node_id: stageID,
          });
        }, 0);
      });
    }
  });
}

function getNodeDataFromID(element) {
  // extract information embedded in the element id
  var id = element.attr('id').replace('#', '').split(',');

  // default info
  var data = {
    id: '-2',
    name: '-',
    status: 'pending',
    focused: 'false',
  };

  // extract from split id
  if (id && id.length == 4) {
    data = {
      id: id[0],
      name: id[1],
      status: id[2],
      focused: id[3],
    };
  }

  return data;
}

function getEdgeDataFromID(element) {
  // extract information embedded in the element id
  var id = element.attr('id').replace('#', '').split(',');

  // default info
  var data = {
    source: '-1',
    destination: '-1',
    status: 'pending',
    focused: 'false',
  };

  // extract from split id
  if (id && id.length >= 4) {
    data = {
      source: id[0],
      destination: id[1],
      status: id[2],
      focused: id[3],
    };
  }

  return data;
}

function getStepDataFromTitle(element) {
  // extract information embedded in the element title
  var title = element.attr('xlink:title').split(',');

  // default info
  var data = {
    id: '-3',
    name: '-',
    status: 'pending',
  };

  // extract from split title
  if (title && title.length >= 2) {
    data = {
      id: title[0],
      name: title[1],
      status: title[2],
    };
  }

  return data;
}
