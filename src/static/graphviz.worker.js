// graphviz.worker.js
import * as wasm from '@hpcc-js/wasm';

let wasmBinaryResolve;
let wasmBinaryReady = new Promise((resolve) => {
  wasmBinaryResolve = resolve;
})

// Handle incoming messages
self.addEventListener(
  'message',
  function (event) {
    const { eventType, wasmBinaryResolve, wasmBinaryReady } = event.data;
    // optimize wasm loading, do not fetch when already loaded
    if (eventType === 'INIT') {
      const { wasmPath } = event.data;
      const wasmBinaryPromise = fetch(wasmPath, { credentials: 'same-origin' })
        .then(res => {
          console.log('fetching wasmbinary')
          if (!res.ok) throw Error(`Failed to load '${wasmPath}'`);
          return res.arrayBuffer();
        })
        .then(bytes => {
          // convert web assembly binary from bytes to int array
          var wasmBinary = new Uint8Array(bytes);
          console.log("resolving wasmBinary")
          wasmBinaryResolve(wasmBinary);
        });
    } else if (eventType === 'LAYOUT') {
      const { eventData } = event.data;
      // use wasmbinary
      console.log('using wasmBinaryReady.then')
      wasmBinaryReady.then((wasmBinaryInstance) => {
        console.log('using preloaded wasmInstance:1')
        // can we preserve this loaded wasm object? and use it to UPDATE with
        wasm.graphviz
          .layout(eventData, 'svg', 'dot', {
            // wasmFolder: wasmFolder,
            wasmBinary: wasmBinaryInstance,
          })
          .then(content => {
            self.postMessage({
              eventType: 'LAYOUT_RESULT',
              eventData: content,
            });
            // close the web worker
            self.close();
          });
      })
    }
  },
  false,
);
