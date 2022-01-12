// Copyright (c) 2021 Target Brands, Inc. All rights reserved.
//
// Use of this source code is governed by the LICENSE file in this repository.

// import types
import * as ClipboardJS from 'clipboard';
import * as d3 from 'd3';
import d3Tip from "d3-tip";
import * as d3Dag from "d3-dag";

// @ts-ignore
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



  // spread the nodes
  const nodeRadius = 50;

  // spread the edges
  const edgeRadius = 20;
app.ports.outboundD3.subscribe(function (inData) {
  // @ts-ignore
  var dagData = inData.links
  console.log(dagData.toString());
  // d = [
  //   ["1", "2"],
  //   ["1", "5"],
  //   ["1", "7"],
  //   ["2", "3"],
  //   ["2", "4"],
  //   ["2", "5"],
  //   ["2", "7"],
  //   ["2", "8"],
  //   ["3", "6"],
  //   ["3", "8"],
  //   ["4", "7"],
  //   ["5", "7"],
  //   ["5", "8"],
  //   ["5", "9"],
  //   ["6", "8"],
  //   ["7", "8"],
  //   ["9", "10"],
  //   ["9", "11"]
  // ]
  // d = [["3","2"],["4","2"],["11","2"],["14","2"],["16","2"],["1","2"],["9","2"],["5","2"],["6","2"],["8","2"],["13","2"],["15","2"],["0","2"],["10","2"],["12","2"],["17","2"],["7","2"],["3","9"],["4","9"],["11","9"],["14","9"],["16","9"],["1","9"],["2","9"],["5","9"],["6","9"],["8","9"],["13","9"],["15","9"],["0","9"],["10","9"],["12","9"],["17","9"],["7","9"],["17","13"],["7","13"],["10","13"],["12","13"],["11","13"],["14","13"],["16","13"],["1","13"],["3","13"],["4","13"],["2","13"],["9","13"],["8","13"],["15","13"],["0","13"],["5","13"],["6","13"],["2","15"],["9","15"],["0","15"],["5","15"],["6","15"],["8","15"],["13","15"],["7","15"],["10","15"],["12","15"],["17","15"],["1","15"],["3","15"],["4","15"],["11","15"],["14","15"],["16","15"],["1","0"],["3","0"],["4","0"],["11","0"],["14","0"],["16","0"],["2","0"],["9","0"],["5","0"],["6","0"],["8","0"],["13","0"],["15","0"],["7","0"],["10","0"],["12","0"],["17","0"],["14","5"],["16","5"],["1","5"],["3","5"],["4","5"],["11","5"],["2","5"],["9","5"],["13","5"],["15","5"],["0","5"],["6","5"],["8","5"],["7","5"],["10","5"],["12","5"],["17","5"],["2","6"],["9","6"],["13","6"],["15","6"],["0","6"],["5","6"],["8","6"],["7","6"],["10","6"],["12","6"],["17","6"],["14","6"],["16","6"],["1","6"],["3","6"],["4","6"],["11","6"],["6","8"],["13","8"],["15","8"],["0","8"],["5","8"],["12","8"],["17","8"],["7","8"],["10","8"],["4","8"],["11","8"],["14","8"],["16","8"],["1","8"],["3","8"],["2","8"],["9","8"],["10","7"],["12","7"],["17","7"],["3","7"],["4","7"],["11","7"],["14","7"],["16","7"],["1","7"],["9","7"],["2","7"],["5","7"],["6","7"],["8","7"],["13","7"],["15","7"],["0","7"],["13","10"],["15","10"],["0","10"],["5","10"],["6","10"],["8","10"],["7","10"],["12","10"],["17","10"],["14","10"],["16","10"],["1","10"],["3","10"],["4","10"],["11","10"],["2","10"],["9","10"],["1","12"],["3","12"],["4","12"],["11","12"],["14","12"],["16","12"],["2","12"],["9","12"],["0","12"],["5","12"],["6","12"],["8","12"],["13","12"],["15","12"],["7","12"],["10","12"],["17","12"],["1","17"],["3","17"],["4","17"],["11","17"],["14","17"],["16","17"],["2","17"],["9","17"],["0","17"],["5","17"],["6","17"],["8","17"],["13","17"],["15","17"],["7","17"],["10","17"],["12","17"],["11","14"],["16","14"],["1","14"],["3","14"],["4","14"],["2","14"],["9","14"],["8","14"],["13","14"],["15","14"],["0","14"],["5","14"],["6","14"],["17","14"],["7","14"],["10","14"],["12","14"],["3","16"],["4","16"],["11","16"],["14","16"],["1","16"],["9","16"],["2","16"],["5","16"],["6","16"],["8","16"],["13","16"],["15","16"],["0","16"],["10","16"],["12","16"],["17","16"],["7","16"],["2","1"],["9","1"],["15","1"],["0","1"],["5","1"],["6","1"],["8","1"],["13","1"],["7","1"],["10","1"],["12","1"],["17","1"],["16","1"],["3","1"],["4","1"],["11","1"],["14","1"],["0","3"],["5","3"],["6","3"],["8","3"],["13","3"],["15","3"],["7","3"],["10","3"],["12","3"],["17","3"],["1","3"],["4","3"],["11","3"],["14","3"],["16","3"],["2","3"],["9","3"],["1","4"],["3","4"],["11","4"],["14","4"],["16","4"],["2","4"],["9","4"],["0","4"],["5","4"],["6","4"],["8","4"],["13","4"],["15","4"],["7","4"],["10","4"],["12","4"],["17","4"],["5","11"],["6","11"],["8","11"],["13","11"],["15","11"],["0","11"],["10","11"],["12","11"],["17","11"],["7","11"],["3","11"],["4","11"],["14","11"],["16","11"],["1","11"],["9","11"],["2","11"]]

  if (!dagData || dagData.length === 0 ) return;

    

  const dag = d3Dag.dagConnect()(dagData);
  console.log(dag)
  // const dag = d3Dag.dagStratify()(d);
  // const width = 1600, height = 500;

  const padding = 1.5;
  const base = nodeRadius * 2 * padding;
  console.log("shouldnt this call fancyLayout")
  const ff = fancyLayout()(dag);
  console.log("fancyLayout returned: ", ff)
  const {width, height} = ff;
      // .sugiyama()
      // // .sugiyama() // base layout
      // .decross(d3Dag.decrossTwoLayer().order(d3Dag.twolayerAgg()))
      // .layering(d3Dag.layeringSimplex())
      // .coord(d3Dag.coordQuad())
      // .nodeSize((node) => {
      //   const size = node ? base : 5;
      //   return [1.2 * size, size];
      // })
      // .nodeSize((node) => [(node ? 3.6 : 0.25) * nodeRadius, 3 * nodeRadius]); // set node size instead of constraining to fit
    // const {width, height} = layout(dag)

      // layout.size([1200, 1200])

      // initialize tooltips
      // var tip = d3Tip()
      // .attr('class', 'd3-tip')
      // .style('color', 'green')
      // .direction('e')
      //     .offset([0, 50])
      //     .html(
      //         function (ev, d) {
      //           var innerSteps = ``;
      //           if (d.data.steps) {
      //             d.data.steps.map((s) => innerSteps = innerSteps + `<tr><td align="left">` + s.name + `</td><td align="left">`+ s.image +`</td></tr>`)
      //            }
      //            else {
      //             innerSteps = `<tr><td></td></tr>`
      //            }
      //             // if (d.data.isUnion) return;
      //             var content = d.data.steps ? `
      //             <table style="margin-top: 2.5px;">
      //             <tr><span style="text-decoration: underline;">steps</span></tr>
      //             <tr><th align="left">name</td><th align="left">image</td></tr>
      //             `+ innerSteps + `</table>                  
      //             ` : `<span/>`
      //             return content.replace(new RegExp("null", "g"), "?")
      //         }
      //     );

    // --------------------------------
    // This code only handles rendering
    // --------------------------------
    
    const check = d3.select("#build-dag svg");
    if (check._groups[0] === null) {
      return;
    }

  console.log("x", [...new Set([...dag].map((n) => n.x))][0]);

  for (const { points } of dag.ilinks()) {
    if (points.length > 2) console.log(points.slice(1, -1));
  }


    const svgSelection = d3.select("#build-dag").append("svg")
    .attr("width", width)
    .attr("height", height)
    // .call(tip);

    // initialize panning, zooming
    var zoom = d3.zoom()
        .on("zoom", (event) => {
          svgSelection.attr("transform", event.transform)
        });





    d3.select("#build-dag").call(zoom);

    // svgSelection.attr("viewbox", `${-nodeRadius} ${-nodeRadius} ${width + 2 * nodeRadius} ${height + 2 * nodeRadius}`);
    const defs = svgSelection.append("defs"); // For gradients
  
    const steps = dag.size();
    const interp = d3.interpolateRainbow;
    const colorMap = new Map();
    // for (const [i, node] of dag.idescendants().entries()) {
    //   colorMap.set(node.data.id, interp(i / steps));
    // }
  
  

  // How to draw edges
  // const line = d3.line()
  //   .curve(d3.curveMonotoneX)
  //   .x(d => d.y)
  //   .y(d => d.x);
    
  // const line = d3.line()
  //   .curve(d3.curveCatmullRom)
  //   .x(d => d.x)
  //   .y(d => d.y);

  // const curveStyle = {
  //   Grid: [d3.curveBasis, d3.curveBasis],
  //   Zherebko: [d3.curveMonotoneY, d3.curveMonotoneX],
  //   Sugiyama: [d3.curveNatural, d3.curveNatural]
  // }[algorithm][+horizontal];

  const line = d3
    .line()
    .curve(d3.curveMonotoneX)
    .x((d) => d.x)
    .y((d) => d.y);



  // Plot edges
  svgSelection
    .append("g")
    .selectAll("path")
    .data(dag.links())
    .enter()
    .append("path")
    .attr("d", ({ points }) => line(points))
    .attr("fill", "none")
    .attr("stroke-width", 2)
    .attr("stroke", ({ source, target }) => {
      // encode URI component to handle special characters
      const gradId = encodeURIComponent(`${source.data.id}-${target.data.id}`);
      const grad = defs
        .append("linearGradient")
        .attr("id", gradId)
        .attr("gradientUnits", "userSpaceOnUse")
        .attr("x1", source.x)
        .attr("x2", target.x)
        .attr("y1", source.y)
        .attr("y2", target.y);
      grad
        .append("stop")
        .attr("offset", "0%")
        .attr("stop-color", colorMap[source.data.id]);
      grad
        .append("stop")
        .attr("offset", "100%")
        .attr("stop-color", colorMap[target.data.id]);
      return `url(#${gradId})`;
    });

  // Select nodes
  const nodes = svgSelection
    .append("g")
    .selectAll("g")
    .data(dag.descendants())
    .enter()
    .append("g")
    .attr("transform", ({x,y}) =>{return `translate(${x}, ${y})`});
  const rectWidth = 100;
  const rectHeight = 50;
  // Plot node circles
  nodes
    // .append("div")
    .append("rect")
    .attr("width", rectWidth)
    .attr("height", rectHeight)
    .attr("x", function(d) { return rectWidth / 2 * -1; })
    .attr("y", function(d) { return rectHeight / 2 * -1; })
    .attr("fill", (n) => {return "black"});

  // Add text to nodes
  nodes
    .append("text")
    .text((d) => {
      // @ts-ignore
      console.log(inData.nodes[d.data.id]); return inData.nodes[d.data.id].label;})
    .attr("font-weight", "bold")
    .attr("font-family", "sans-serif")
    .attr("text-anchor", "middle")
    .attr("alignment-baseline", "middle")
    .attr("fill", "white")
    // .style("font-size", (d) => { console.log(this); console.log(d);var r = Math.min(2 * d.r, (2 * d.r - 8) / this.getComputedTextLength() * 24) + "px"; console.log(r); return r;})

    // Plot edges
    // svgSelection
    //   .append("g")
    //   .selectAll("path")
    //   .data(dag.links())
    //   .enter()
    //   .append("path")
    //   .attr("d", ({ points }) => line(points))
    //   .attr("fill", "none")
    //   .attr("stroke-width", 3)
    //   .attr("stroke", ({ source, target }) => {
    //     // encodeURIComponents for spaces, hope id doesn't have a `--` in it
    //     const gradId = encodeURIComponent(`${source.data.id}--${target.data.id}`);
    //     const grad = defs
    //       .append("linearGradient")
    //       .attr("id", gradId)
    //       .attr("gradientUnits", "userSpaceOnUse")
    //       .attr("x1", source.x)
    //       .attr("x2", target.x)
    //       .attr("y1", source.y)
    //       .attr("y2", target.y);
    //     grad
    //       .append("stop")
    //       .attr("offset", "0%")
    //       .attr("stop-color", colorMap.get(source.data.id));
    //     grad
    //       .append("stop")
    //       .attr("offset", "100%")
    //       .attr("stop-color", colorMap.get(target.data.id));
    //     return `url(#${gradId})`;
    //   });


    // // Select nodes
    // const nodes = svgSelection
    //   .append("g")
    //   .selectAll("g")
    //   .data(dag.descendants())
    //   .enter()
    //   .append("g")
    //   .attr('transform', ({x, y}) => `translate(${x * 10}, ${y * 10})`);
    //   // .on('mouseover', tip.show)
    //   // .on('mouseout', tip.hide);
  
    // // Plot node circles
    // nodes
    //   .append("circle")
    //   .attr("r", nodeRadius)
    //   .attr("fill", (n) => colorMap.get(n.data.id));

    // // Add text to nodes
    // nodes
    //   .append("text")
    //   .text((d) => {console.log(inData.nodes[d.data.id]); return inData.nodes[d.data.id].label;})
    //   .attr("font-weight", "bold")
    //   .attr("font-family", "sans-serif")
    //   .attr("text-anchor", "middle")
    //   .attr("alignment-baseline", "middle")
    //   .attr("fill", "white");



      // layout(dag)

  // setTimeout(() => app.ports.inboundD3.send(outboundString), 0);


  function gridTweak(){
    console.log("returning gridTweak func")
    console.log(nodeRadius)
    console.log(edgeRadius)
    return(
    (layout) => (dag) => {
      console.log("calling gridTweak layout:")
      console.log(layout)
      // Tweak allows a basis interpolation to curve the lines
      // We essentially take the three point lines and make them five, with two points on either side of the bend
      const { width, height } = layout(dag);
      console.log("gridTweak layout returned:", { width, height } )

      for (const { points } of dag.ilinks()) {
        const [first, middle, last] = points;
        if (last !== undefined) {
          points.splice(
            0,
            3,
            first,
            {
              x: middle.x + Math.sign(first.x - middle.x) * nodeRadius,
              y: middle.y
            },
            middle,
            { x: middle.x, y: middle.y + nodeRadius },
            last
          );
        }
      }
      return { width, height };
    }
    )};

  function gridCompact(){
    console.log("returning gridCompact func")
    console.log(nodeRadius)
    console.log(edgeRadius)
    return(
    (layout) => (dag) => {
      // Tweak to render compact grid, first shrink x width by edge radius, then expand the width to account for the loss
      // This could alos be accomplished by just changing the coordinates of the svg viewbox.
      const baseLayout = layout.nodeSize([
        nodeRadius + edgeRadius * 2,
        (nodeRadius + edgeRadius) * 2
      ]);

      const { width, height } = baseLayout(dag);

      console.log("gridCompact baseLayout returned:", { width, height } )

      for (const node of dag) {
        node.x += nodeRadius;
      }
      
      for (const { points } of dag.ilinks()) {
        for (const point of points) {
          point.x += nodeRadius;
        }
      }

      console.log("gridCompact final return:", { width: width + 2 * nodeRadius, height: height } )
      return { width: width + 2 * nodeRadius, height: height };
    }
    )};




    function fancyLayout() {
      const baseLayout = gridCompact()(d3Dag.grid());
      if (true) {
        return baseLayout;
      } else {
        // flip dag horizontally
        return (dag) => {
          const { width, height } = baseLayout(dag);

          for (const node of dag) {
            // [node.x, node.y] = [node.y, node.x];
          }
          for (const { points } of dag.ilinks()) {
            for (const point of points) {
              // [point.x, point.y] = [point.y, point.x];
            }
          }

          return { width: height, height: width };
        };
    }
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
