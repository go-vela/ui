// graphviz.worker.js
import * as wasm from '@hpcc-js/wasm';
import WASM_PATH from 'url:@hpcc-js/wasm/dist/graphvizlib.wasm';

// Handle incoming messages
self.addEventListener(
  'message',
  function (event) {
    const { eventType, eventData } = event.data;
    // optimize wasm loading, do not fetch when already loaded
    if (eventType === 'LAYOUT') {
      const wasmBinaryPromise = fetch(WASM_PATH, { credentials: 'same-origin' })
        .then(res => {
          if (!res.ok) throw Error(`Failed to load '${WASM_PATH}'`);
          return res.arrayBuffer();
        })
        .then(bytes => {
          // convert web assembly binary from bytes to int array
          var wasmBinary = new Uint8Array(bytes);
          
          // can we preserve this loaded wasm object? and use it to UPDATE with
          wasm.graphviz
            .layout(eventData, 'svg', 'dot', {
              wasmFolder: WASM_PATH,
              wasmBinary: wasmBinary,
            })
            .then(content => {
              self.postMessage({
                eventType: 'LAYOUT_RESULT',
                eventData: content,
              });
              // close the web worker
              self.close();
            });
        });
    }
  },
  false,
);
