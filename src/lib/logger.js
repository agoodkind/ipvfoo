"use strict";

import {DEBUG} from "./common.js";

export function debugLog(...args) {
  if (!DEBUG) {
    return;
  }
  const timestamp = new Date().toISOString();
  console.log(timestamp, ...args);
}
