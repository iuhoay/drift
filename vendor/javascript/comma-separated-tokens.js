// comma-separated-tokens@2.0.3 downloaded from https://ga.jspm.io/npm:comma-separated-tokens@2.0.3/index.js

/**
 * @typedef Options
 *   Configuration for `stringify`.
 * @property {boolean} [padLeft=true]
 *   Whether to pad a space before a token.
 * @property {boolean} [padRight=false]
 *   Whether to pad a space after a token.
 */
/**
 * @typedef {Options} StringifyOptions
 *   Please use `StringifyOptions` instead.
 */
/**
 * Parse comma-separated tokens to an array.
 *
 * @param {string} value
 *   Comma-separated tokens.
 * @returns {Array<string>}
 *   List of tokens.
 */
function parse(t){
/** @type {Array<string>} */
const n=[];const e=String(t||"");let i=e.indexOf(",");let r=0;
/** @type {boolean} */let s=false;while(!s){if(-1===i){i=e.length;s=true}const t=e.slice(r,i).trim();!t&&s||n.push(t);r=i+1;i=e.indexOf(",",r)}return n}
/**
 * Serialize an array of strings or numbers to comma-separated tokens.
 *
 * @param {Array<string|number>} values
 *   List of tokens.
 * @param {Options} [options]
 *   Configuration for `stringify` (optional).
 * @returns {string}
 *   Comma-separated tokens.
 */function stringify(t,n){const e=n||{};const i=""===t[t.length-1]?[...t,""]:t;return i.join((e.padRight?" ":"")+","+(false===e.padLeft?"":" ")).trim()}export{parse,stringify};

