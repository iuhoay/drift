// space-separated-tokens@2.0.2 downloaded from https://ga.jspm.io/npm:space-separated-tokens@2.0.2/index.js

/**
 * Parse space-separated tokens to an array of strings.
 *
 * @param {string} value
 *   Space-separated tokens.
 * @returns {Array<string>}
 *   List of tokens.
 */
function parse(r){const t=String(r||"").trim();return t?t.split(/[ \t\n\r\f]+/g):[]}
/**
 * Serialize an array of strings as space separated-tokens.
 *
 * @param {Array<string|number>} values
 *   List of tokens.
 * @returns {string}
 *   Space-separated tokens.
 */function stringify(r){return r.join(" ").trim()}export{parse,stringify};

