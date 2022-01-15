// Copyright (c) 2021 Target Brands, Inc. All rights reserved.
//
// Use of this source code is governed by the LICENSE file in this repository.

// import types
import * as ClipboardJS from 'clipboard';
import * as d3 from 'd3';
import * as wasm from '@hpcc-js/wasm';

// @ts-ignore // false negative module warning
import * as graphviz from './graphviz.min.js';
// @ts-ignore // false negative module warning
import otherWasmUrl from 'url:./graphvizlib.wasm';

// @ts-ignore // false negative module warning
import wasmUrl from 'url:@hpcc-js/wasm/dist/graphvizlib.wasm';

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

app.ports.outboundD3.subscribe(function (dotGraph) {
  const foundSvg = d3.select(".build-graph");
  const svg = createSvg(foundSvg)
  const WASM_PATH='';

  console.log('using wasm to layout with wasmBinary: wasmUrl', wasmUrl)
  console.log('what about this wasm_path???', otherWasmUrl)

  // WebAssembly.instantiateStreaming(fetch(WASM_PATH), importObject)
  // .then(results => {
  //   // Do something with the results!
  // });

  console.log('rendering');
  console.log(wasmUrl);
  console.log(graphviz);
  //   svg.html(content);
  console.log('getting');

 
  wasmWorker("./calculator.wasm", wasmUrl).then((wasmProxyInstance) => {
    console.log('got proxy instance')
    wasmProxyInstance.add(2, 3)
        .then((result) => {
            console.log(result); // 5
        })
        .catch((error) => {
            console.log('error proxy 1')
            console.error(error);
        });
 
    wasmProxyInstance.divide(100, 10)
        .then((result) => {
            console.log(result); // 10
        })
        .catch((error) => {
          console.log('error proxy 2')
            console.error(error);
        });
});

  
  // graphviz.graphviz.layout(dotGraph, "svg", "dot", {
  //   // wasmFolder: wasmUrl,
  //   // wasmBinary: wasmBinary
  // }).then(content => {
  //     svg.html(content);
  // })

  // const wasmBinaryPromise = fetch(otherWasmUrl, { credentials: 'same-origin' })
  // .then(res => {
  //   if (!res.ok) throw Error(`Failed to load '${otherWasmUrl}'`);
  //   return res.arrayBuffer();
  // })
  // .then(ab => {
  //   console.log("got ab")
  //   var wasmBinary = new Uint8Array(ab);
  //   console.log(wasmBinary);
  //   console.log("wasm layout...");
  //   console.log(otherWasmUrl);

  //   graphviz.graphviz.layout(dotGraph, "svg", "dot", {
  //     // wasmFolder: wasmUrl,
  //     // wasmBinary: wasmBinary
  //   }).then(content => {
  //       svg.html(content);
  //   })

  //   // wasm.graphviz.layout(dotGraph, "svg", "dot", {
  //   //   wasmFolder: wasmUrl,
  //   //   wasmBinary: wasmBinary
  //   // }).then(content => {
  //   //   svg.html(content);
  //   // });
  //   //   svg.selectAll('title').remove();
  //   //   svg.selectAll('*').attr('xlink:title', null);
  
  //   //   var bbox = svg.node().getBBox();
  //   //   const VIEWBOX_PADDING = { x1: 20, x2: 40, y1: 20, y2: 40} 
  //   //   d3.select(svg.node().parentNode)
  //   //     .attr("viewBox", "" + (bbox.x - VIEWBOX_PADDING.x1) + " " + (bbox.y - VIEWBOX_PADDING.y1) + " " + (bbox.width + VIEWBOX_PADDING.x2) + " " + (bbox.height + VIEWBOX_PADDING.y2))
  //   // })
  // });

 

});

function createSvg(svg) {
  var g = d3.select("g.test")
  if (g.empty()) {
    svg.append("defs").append("filter")
      .attr("id", "embiggen")
      .append("feMorphology")
      .attr("operator", "dilate")
      .attr("radius", "4");

    g = svg.append("g").attr("class", "test")
    svg.on("mousedown", (e, d) => {
      if (e.button || e.ctrlKey) {
        console.log("button or ctrl");
        e.stopImmediatePropagation();
      }
    });
  }
  return g
}

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









// wasmWorker


function wasmWorker(modulePath, wasmPath) {
 
  // Create an object to later interact with 
  const proxy = {};

  // Keep track of the messages being sent
  // so we can resolve them correctly
  let id = 0;
  let idPromises = {};

  return new Promise((resolve, reject) => {
      const worker = new Worker(new URL('./worker.js', import.meta.url));
      console.log("posting using ", wasmPath)
      worker.postMessage({eventType: "INITIALISE", eventData: modulePath, wasmPath: wasmPath});
      worker.addEventListener('message', function(event) {

          const { eventType, eventData, eventId } = event.data;

          if (eventType === "INITIALISED") {
              const methods = event.data.eventData;
              methods.forEach((method) => {
                  proxy[method] = function() {
                      return new Promise((resolve, reject) => {
                          worker.postMessage({
                              eventType: "CALL",
                              eventData: {
                                  method: method,
                                  arguments: Array.from(arguments) // arguments is not an array
                              },
                              eventId: id
                          });

                          idPromises[id] = { resolve, reject };
                          id++
                      });
                  }
              });
              resolve(proxy);
              return;
          } else if (eventType === "RESULT") {
              if (eventId !== undefined && idPromises[eventId]) {
                  idPromises[eventId].resolve(eventData);
                  delete idPromises[eventId];
              }
          } else if (eventType === "ERROR") {
              if (eventId !== undefined && idPromises[eventId]) {
                  idPromises[eventId].reject(event.data.eventData);
                  delete idPromises[eventId];
              }
          }
           
      });

      worker.addEventListener("error", function(error) {
          reject(error);
      });
  })

}