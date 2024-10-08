// SPDX-License-Identifier: Apache-2.0

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
  /** @property velaTheme: Theme | null */
  readonly velaTheme: Theme;
  /** @property velaRedirect: string */
  readonly velaRedirect: string;
  /** @property velaLogBytesLimit: number */
  readonly velaLogBytesLimit: number;
  /** @property velaMaxBuildLimit: number */
  readonly velaMaxBuildLimit: number;
  /** @property velaMaxStarlarkExecLimit: number */
  readonly velaMaxStarlarkExecLimit: number;
  /** @property velaScheduleAllowlist: string */
  readonly velaScheduleAllowlist: string;
};

/**
 * Defines the ports that are set up in Elm
 *
 */
export type Ports = {
  readonly setTheme: ToJS<Theme>;
  readonly setRedirect: ToJS<string>;
  readonly setFavicon: ToJS<string>;
  readonly onThemeChange: ToElm<Theme>;
  readonly renderBuildGraph: ToJS<GraphData>;
  readonly onGraphInteraction: ToElm<GraphInteraction>;
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
 * Supported themes
 *
 */
export type Theme = 'theme-light' | 'theme-dark';

/**
 * Build graph
 *
 */
export type GraphData = {
  /** @property dot: string */
  dot: string;
  /** @property buildID: number */
  buildID: number;
  /** @property filter: string */
  filter: string;
  /** @property focusedNode: number */
  focusedNode: number;
  /** @property showServices: boolean */
  showServices: boolean;
  /** @property showSteps: boolean */
  showSteps: boolean;
  /** @property freshDraw: boolean */
  freshDraw: boolean;
};

export type GraphInteraction = {
  /** @property eventType: string */
  eventType: string;
  /** @property href: string */
  href: string;
  /** @property nodeID: string */
  nodeID: string;
};
