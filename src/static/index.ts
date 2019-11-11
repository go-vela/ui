// Copyright (c) 2019 Target Brands, Inc. All rights reserved.
//
// Use of this source code is governed by the LICENSE file in this repository.

import { Elm, Flags, App, Config, Session } from "../elm/Main";
import "../scss/style.scss";

// setup for session state
const storageKey: string = "vela";
const storedSessionState: string | null = sessionStorage.getItem(storageKey);
const currentSessionState: Session | null = storedSessionState
  ? JSON.parse(storedSessionState)
  : null;

// Vela flags; configuration for bootstrapping Vela Elm UI
const flags: Flags = {
  isDev: process.env.NODE_ENV === "development",
  velaAPI: process.env.VELA_API || "$VELA_API",
  velaSourceBaseURL: process.env.VELA_SOURCE_URL || "$VELA_SOURCE_URL",
  velaSourceClient: process.env.VELA_SOURCE_CLIENT || "$VELA_SOURCE_CLIENT",
  velaSession: currentSessionState || null
};

// create the configuration object for Elm
const config: Config = {
  node: null, // not passing an HTML node will let Elm take over the whole page
  flags: flags
};

// bootstrap the app
const app: App = Elm.Main.init(config);

// subscribe to session events sent from Elm
app.ports.storeSession.subscribe(sessionMessage => {
  if (sessionMessage === null || sessionMessage.token === "") {
    sessionStorage.removeItem(storageKey);
  } else {
    sessionStorage.setItem(storageKey, JSON.stringify(sessionMessage));
  }

  setTimeout(() => app.ports.onSessionChange.send(sessionMessage), 0);
});
