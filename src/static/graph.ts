// Copyright (c) 2022 Target Brands, Inc. All rights reserved.
//
// Use of this source code is governed by the LICENSE file in this repository.

// todo: remove
// @ts-nocheck
import * as d3 from 'd3';

export function drawGraph(opts, content) {
  // force d3 exports to resolve, required or we receive errors when running within a container
  // this is why we love javascript
  var _ = d3;

  // todo: (kelly) make non-focused edges/outlines less "in your face" until you engage with
  // todo: group/label services subgraph

  // define DOM selectors for DOT-generated elements
  var graphSelectors = {
    root: '.elm-build-graph-root',
    node: '.elm-build-graph-node',
    edge: '.elm-build-graph-edge',
  };

  var buildGraphElement = drawBaseGraph(opts, graphSelectors.root, content);

  // check that a valid graph was rendered
  if (buildGraphElement.node() == null) {
    console.log('unable to continue drawing graph, root element is invalid');
    return;
  }

  drawViewbox(opts, buildGraphElement);

  // apply onclick to base node links prior to adding/removing elements
  applyNodesOnClick(opts, buildGraphElement, graphSelectors.node);

  var edges = drawEdges(opts, buildGraphElement, graphSelectors.edge);

  drawNodes(opts, buildGraphElement, graphSelectors.node, edges);
}

function drawBaseGraph(opts, selector, content) {
  // grab the build graph root element
  var buildGraphElement = d3.select(selector);

  var zoom = d3.zoom()
    .scaleExtent([0.1, Infinity])
    .on('zoom', handleZoom);

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
    zoomG
      .attr('transform', event.transform);
  }

  var w = 0;
  var h = 0;
  function resetZoomAndCenter(opts, zoom) {
    var zoomG = d3.select(selector);

    // reset zoom scale to 1
    zoomG.call(zoom.scaleTo, 1);

    // the name of this variable is confusing
    var zoomGg = d3.select(selector);
    var zoomBBox = zoomGg.node().getBBox();
    w = zoomBBox.width;
    h = zoomBBox.height;
    zoomGg
      .transition() // required to 'chain' these two instant animations together
      .duration(0)
      .call(zoom.translateTo, w * 0.5, h * 0.5)
  }

  // enable d3 zoom and pan functionality
  buildGraphElement.call(zoom);

  var actionResetPan = d3.select('#action-center');

  // apply zoom onclick
  actionResetPan.on('click', function (e) {
    e.preventDefault();
    resetZoomAndCenter(opts, zoom);
  });

  // apply mousedown zoom effects
  var g = d3.select('g.node_mousedown');
  if (g.empty()) {
    var zoomG = d3.select(selector);
    var zoomBBox = zoomG.node().getBBox();
    w = zoomBBox.width;
    h = zoomBBox.height;
    g = buildGraphElement
      .append('g');
    g.classed('node_mousedown', true)
      .attr('id', 'zoom');
  }

  // apply backdrop onclick
  buildGraphElement.on('click', function (e) {
    e.preventDefault();
    setTimeout(
      () => {
        opts.onGraphInteraction.send({
          event_type: 'backdrop_click',
        });
      }, 0
    );
  });

  // this centers the graph in the viewbox, or something like that
  buildGraphElement = g;

  // draw content into html
  buildGraphElement.html(content);

  // reset the graph when the build number has changed
  if (!opts.isRefreshDraw) {
    resetZoomAndCenter(opts, zoom);
  }

  // todo: detect a tab-switch and reset the zoom. currently it puts the graph in the top-left origin
  // if (!opts.isTabSwitch) {
  //   resetZoomAndCenter(opts, zoom);
  // }

  return buildGraphElement;
}

function drawViewbox(opts, buildGraphElement) {
  var graphBBox = buildGraphElement.node().getBBox();

  // apply viewbox properties to the root element's parent
  // provide x padding for the legend
  const VIEWBOX_PADDING = { x1: 0, x2: 500, y1: 0, y2: 100 };

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

function drawNodes(opts, buildGraphElement, selector, edges) {
  buildGraphElement.selectAll(selector).filter(function () {
    let stageNode = d3.select(this);

    // apply an outline using rect, since nodes are rect and this will allow for animation
    var outline = stageNode.append('rect');
    var nodeBBox = stageNode.node().getBBox();
    outline
      .attr('x', nodeBBox.x)
      .attr('y', nodeBBox.y)
      .attr('width', nodeBBox.width)
      .attr('height', nodeBBox.height);

    var stageInfo = stageNode.attr('id').replace('#', '').split(',');
    var stageID = '-2';
    var stageName = '';
    var stageStatus = 'pending';
    var focused = 'false';
    if (stageInfo && stageInfo.length == 4) {
      stageID = stageInfo[0];
      stageName = stageInfo[1];
      stageStatus = stageInfo[2];
      focused = stageInfo[3];
    }


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

    // apply appropriate node outline styles
    restoreNodeClass(outline);

    // todo: this doesnt work with its own class
    if (focused && focused === 'true') {
      restoreNodeClass = o => {
        // todo: would be cool to animate this
        o.classed('-hover', true);
      };
    }

    // todo: we shouldnt need to run this twice
    // just apply the "running" outline/animation on top of the hover...
    restoreNodeClass(outline);

    // apply stage node styles
    stageNode.on('mouseover', e => {
      outline.classed('-hover', true);

      // take this stage and
      // filter out all the edges that arent source/dest of each edge
      edges.filter(function (edgeInfo) {
        if (stageID === edgeInfo.source ||
          stageID === edgeInfo.destination) {
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
        if (stageID === edgeInfo.source ||
          stageID === edgeInfo.destination) {
          var status = edgeInfo.status;

          // apply edge element hover styles
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

          if (edgeInfo.focused === 'true') {
            restoreEdgeClass = o => {
              o.classed('-hover', true);
            };
          }

          // apply the appropriate styles
          restoreEdgeClass(edgeInfo.target);
        }
      });
    });

    var stepIconSize = 16;
    stageNode.selectAll('a').filter(function () {
      var step = d3.select(this);
      if (step.attr('xlink:href').includes('#step')) {

        // restore base class and build modifiers
        step.attr('class', 'd3-build-graph-node-step-a');

        // apply an outline using rect, since nodes are rect and this will allow for animation
        var underline = step.append('rect');
        var aBBox = step.node().getBBox();
        underline
          .attr('x', aBBox.x + stepIconSize)
          .attr('y', aBBox.y + aBBox.height)
          .attr('width', aBBox.width - stepIconSize)
          .attr('fill', 'var(--color-red)'); //todo: replace with style

        // restore base class and build modifiers
        underline.attr('class', 'd3-build-graph-node-step-a-underline');

        // apply step table row hover styles
        step.on('mouseover', e => {
          step.classed('-hover', true);
          underline.classed('-hover', true);
          underline.attr('height', 1);
        });
        step.on('mouseout', e => {
          step.classed('-hover', false);
          underline.classed('-hover', false);
          underline.attr('height', 0);
        });
      }
    });

    // track step number for applying styles
    var i = 0;
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
        var status = 'pending';
        if (stepInfo && stepInfo.length > 2) {
          status = stepInfo[2];
        }

        // todo: this image step icon mapping needs to be better
        if (status === 'canceled') {
          status = 'failure';
        }

        if (status === 'skipped') {
          status = 'failure';
        }

        // todo: static/*.png seems like a bad way to do icon images
        parent
          .append('image')
          .attr('xlink:href', '/images/vela_' + status + '.png')
          .attr('x', nodeBox.x - 6)
          .attr('y', nodeBox.y)
          .attr('width', stepIconSize)
          .attr('height', stepIconSize);

        // step connector
        if (i > 0) {
          parent.append('rect')
            // tweak position for visual effect
            .attr('x', nodeBox.x + 2)
            .attr('y', nodeBox.y - 7)
            // apply size manually
            .attr('width', 1)
            .attr('height', 5)
            .attr('fill', 'var(--color-gray)'); //todo: replace with style
        }
        i++;

        parent.on('click', function (e) {
          e.preventDefault();
          // prevents multiple link events getting fired from a single click
          e.stopImmediatePropagation();
          setTimeout(
            () => {
              opts.onGraphInteraction.send({
                event_type: 'href',
                href: href,
                step_id: '',
              });
            },
            0,
          );
        });
      }
    });

    return ''; // used by filter (?)
  });
}

function drawEdges(opts, buildGraphElement, selector) {
  // collect edge information to use in other d3 interactivity
  var edges = [];

  buildGraphElement.selectAll(selector).filter(function () {
    let a = d3.select(this);
    var edgeInfo = a.attr('id').replace('#', '').split(',');
    var p = a.select('path');

    // extract edge information
    var source = "-1";
    var destination = "-1";
    var status = "pending";
    var focused = "false";
    if (edgeInfo && edgeInfo.length == 4) {
      source = edgeInfo[0];
      destination = edgeInfo[1];
      status = edgeInfo[2];
      focused = edgeInfo[3];
    }

    // track edge information for advanced styling
    edges.push({
      target: p,
      source: source,
      destination: destination,
      status: status,
      focused: focused,
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

    // apply the appropriate styles
    restoreEdgeClass(p);


    if (focused && focused === 'true') {
      restoreEdgeClass = o => {
        o.classed('-hover', true);
      };
    }

    // apply the appropriate styles
    restoreEdgeClass(p);

    // apply edge hover styles
    // a.on('mouseover', e => {
    //   p.classed('-hover', true);
    // });
    // a.on('mouseout', e => {
    //   restoreEdgeClass(p);
    //   p.classed('-hover', false);
    // });

    return ''; // used by filter (?)
  });

  return edges;
}

// applyNodesOnClick takes root graph element, selects node links and applies onclick functionality
function applyNodesOnClick(opts, buildGraphElement, selector) {
  // process and return all 'linked' stage nodes
  return buildGraphElement.selectAll(selector + ' a').filter(function () {
    // todo: figure out .each
    // add onclick to nodes with valid href attributes
    var href = d3.select(this).attr('xlink:href');
    if (href !== null) {
      d3.select(this).on('click', function (e) {
        e.preventDefault();
        e.stopImmediatePropagation();

        var nodeA = d3.select(this);
        nodeA.attr('xlink:href', null);

        var stageInfo = nodeA.attr('xlink:title').replace('#', '').split(',');
        var stageID = '-1';
        if (stageInfo && stageInfo.length == 4) {
          stageID = stageInfo[0];
        }

        setTimeout(
          () => {
            opts.onGraphInteraction.send({
              event_type: 'node_click',
              node_id: stageID,
            });
          }, 0
        );
      });
    }
    return '';
  });
}
