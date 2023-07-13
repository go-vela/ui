// graphviz.worker.js
//
// This file contains source code for the graphviz Web Worker.
// The graphviz Web Worker performs the heavy lifting for converting a DOT graph string
//   to HTML content that can be rendered by the UI using D3.
//
// The main purpose behind using the Web Worker API is to satisfy the Content Security Policy
//   that restricts 'script-src' to 'self', disallowing the browser from compiling code in the main thread,
//   which protects from cross-site scripting and other attack vectors.
//   By using a Web Worker, supported browsers can offload the work to a background process.
//   The Web Worker is responsible for:
//     - fetching the Web Assembly binary from WASM_PATH (node_modules/@hpcc-js/wasm/dist/graphvizlib.wasm)
//     - converting DOT to HTML using graphviz

// The graphviz Web Worker requires the use of the npm package '@hpcc-js/wasm' to solve a broad problem with
//   using Parcel and the Graphviz javascript library. By default, the Graphviz javascript library looks for a static copy of the
//   graphviz web assembly binary in /dist/public/graphvizlib.wasm. Due to Parcel compilation our binary ends up in the location /dist/public/graphvizlib.abc123xyz.wasm.
//   for example, see this particular report on d3-graphviz: https://github.com/magjac/d3-graphviz/issues/191
//   '@hpcc-js/wasm' provides a solution for compiling graphviz with Parcel that is well maintained. see: https://github.com/hpcc-systems/hpcc-js-wasm
import * as graphviz from '@hpcc-js/wasm';
import WASM_PATH from 'url:@hpcc-js/wasm/dist/graphvizlib.wasm';

let graphvizWebAssemblyBinaryResolve;
let graphvizWebAssemblyBinaryPromise = new Promise(resolve => {
  graphvizWebAssemblyBinaryResolve = resolve;
});

// message listener for the graphviz Web Worker which is responsible for handling incoming messages:
// - INIT: fetches the graphvizWebAssemblyBinary directly from WASM_PATH (node_modules/@hpcc-js/wasm/dist/graphvizlib.wasm)
//           this step is required due to Parcel path compilation.
//            for more information read the comments at the top of this file.
// - LAYOUT: takes 'dot' graph string and converts it to HTML using graphviz.graphviz.layout and the fetched graphvizWebAssemblyBinary
self.addEventListener(
  'message',
  function (event) {
    const { eventType } = event.data;
    if (eventType === 'INIT') {
      fetch(WASM_PATH)
        .then(res => {
          if (!res.ok)
            throw Error(
              `error loading graphvizWebAssemblyBinary: '${WASM_PATH}'`,
            );
          return res.arrayBuffer();
        })
        .then(bytes => {
          // convert web assembly binary from bytes to int array
          var wasmBinary = new Uint8Array(bytes);
          graphvizWebAssemblyBinaryResolve(wasmBinary);
        });
      // fetch error??
    } else if (eventType === 'LAYOUT') {
      const { dot } = event.data;
      graphvizWebAssemblyBinaryPromise.then(graphvizWebAssemblyBinary => {
        graphviz.graphviz
          .layout(dot, 'svg', 'dot', {
            wasmBinary: graphvizWebAssemblyBinary,
          })
          .then(content => {
            self.postMessage({
              eventType: 'DRAW',
              drawContent: content,
            });
          }); // resolve error??
      });
    }
  },
  false,
);
