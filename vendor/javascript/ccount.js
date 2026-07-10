// ccount@2.0.1 downloaded from https://ga.jspm.io/npm:ccount@2.0.1/index.js

/**
 * Count how often a character (or substring) is used in a string.
 *
 * @param {string} value
 *   Value to search in.
 * @param {string} character
 *   Character (or substring) to look for.
 * @return {number}
 *   Number of times `character` occurred in `value`.
 */
function ccount(t,e){const n=String(t);if("string"!==typeof e)throw new TypeError("Expected character");let r=0;let c=n.indexOf(e);while(-1!==c){r++;c=n.indexOf(e,c+e.length)}return r}export{ccount};

