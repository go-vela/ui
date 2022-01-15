// worker.js
import * as wasm from '@hpcc-js/wasm';
import wasmUrl from 'url:@hpcc-js/wasm/dist/graphvizlib.wasm';

// Handle incoming messages
self.addEventListener('message', function (event) {
    const { eventType, eventData, eventId } = event.data;
    // optimize wasm loading, do not fetch when already loaded
    if (eventType === "INITIALISE") {
        const wasmBinaryPromise = fetch(wasmUrl, { credentials: 'same-origin' })
            .then(res => {
                if (!res.ok) throw Error(`Failed to load '${wasmUrl}'`);
                return res.arrayBuffer();
            })
            .then(bytes => {
                var wasmBinary = new Uint8Array(bytes);
                // can we preserve this loaded wasm object? and use it to UPDATE with
                wasm.graphviz.layout(eventData, "svg", "dot", {
                    wasmFolder: wasmUrl,
                    wasmBinary: wasmBinary
                }).then(content => {
                    console.log("posting message to self: RESULT")
                    self.postMessage({
                        eventType: "RESULT",
                        eventData: content,
                        eventId: eventId
                    });
                });
            })
    }
}, false);