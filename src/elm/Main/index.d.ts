/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

/* Vela Typescript type definitions to encourage end-to-end type safety
 *
 * references:
 * - https://github.com/Punie/elm-typescript-starter/blob/master/src/elm/Main/index.d.ts
 * - https://github.com/dillonkearns/elm-typescript-interop
 */

export module Elm.Main {
  /**
   * Initializes the Elm app with the provided configuration
   *
   * @returns an instance of our bootstrapped Elm app
   */
  function init(config: Config): App;
}

/**
 * Minimal definition of an Elm App instance
 *
 */
export interface App {
  readonly ports: Ports;
}

/**
 * The Elm configuration object.
 *
 * @param node The node the Elm app should mount to; null makes Elm take over the whole app
 * @param flags The settings to bootstrap the Elm app with
 */
export type Config = {
  readonly node?: HTMLElement | null;
  readonly flags: Flags;
};

/**
 * Vela's custom flag configuration
 *
 */
export type Flags = {
  /** @property isDev a helper we might need to determine whether we are running in dev mode */
  readonly isDev: boolean;
  /** @property velaAPI the API of the server that the UI will interface with */
  readonly velaAPI: string;
  /** @property velaFeedbackURL allows you to customize the destination of the feedback link */
  readonly velaFeedbackURL: string;
  /** @property velaDocsURL allows you to customize the destination of the docs link */
  readonly velaDocsURL: string;
  /** @property velaSession used for passsing in an existing Vela session to Elm */
  readonly velaSession: Session | null;
  /** @property velaTheme: Theme | null */
  readonly velaTheme: Theme;
};

/**
 * Defines the ports that are set up in Elm
 *
 */
export type Ports = {
  readonly storeSession: ToJS<Session>;
  readonly onSessionChange: ToElm<Session>;
  readonly setTheme: ToJS<Theme>;
  readonly setFavicon: ToJS<string>;
  readonly onThemeChange: ToElm<Theme>;
  readonly base64Decode: ToJS<string[]>;
  readonly onBase64Decode: ToElm<String[]>;
};

/**
 * Allows for un/subscribing to messages sent from Elm to JS
 *
 */
export type ToJS<T> = {
  subscribe(callback: (value: T) => void): void;
  unsubscribe(callback: (value: T) => void): void;
};

/**
 * Allows for sending messages from JS to Elm
 *
 */
export type ToElm<T> = {
  send(value: T): void;
};

/**
 * The shape of session that we are working with in Vela
 *
 */
export type Session = {
  readonly username: string;
  readonly token: string;
  readonly entrypoint: string;
};

/**
 * Supported themes
 *
 */
export type Theme = 'theme-light' | 'theme-dark';
