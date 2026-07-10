// stringify-entities@4.0.4 downloaded from https://ga.jspm.io/npm:stringify-entities@4.0.4/index.js

import{characterEntitiesLegacy as t}from"character-entities-legacy";import{characterEntitiesHtml4 as e}from"character-entities-html4";
/**
 * @typedef CoreOptions
 * @property {ReadonlyArray<string>} [subset=[]]
 *   Whether to only escape the given subset of characters.
 * @property {boolean} [escapeOnly=false]
 *   Whether to only escape possibly dangerous characters.
 *   Those characters are `"`, `&`, `'`, `<`, `>`, and `` ` ``.
 *
 * @typedef FormatOptions
 * @property {(code: number, next: number, options: CoreWithFormatOptions) => string} format
 *   Format strategy.
 *
 * @typedef {CoreOptions & FormatOptions & import('./util/format-smart.js').FormatSmartOptions} CoreWithFormatOptions
 */const r=/["&'<>`]/g;const n=/[\uD800-\uDBFF][\uDC00-\uDFFF]/g;const o=/[\x01-\t\v\f\x0E-\x1F\x7F\x81\x8D\x8F\x90\x9D\xA0-\uFFFF]/g;const s=/[|\\{}()[\]^$+*?.]/g;
/** @type {WeakMap<ReadonlyArray<string>, RegExp>} */const c=new WeakMap;
/**
 * Encode certain characters in `value`.
 *
 * @param {string} value
 * @param {CoreWithFormatOptions} options
 * @returns {string}
 */function core(t,e){t=t.replace(e.subset?charactersToExpressionCached(e.subset):r,basic);return e.subset||e.escapeOnly?t:t.replace(n,surrogate).replace(o,basic)
/**
   * @param {string} pair
   * @param {number} index
   * @param {string} all
   */;function surrogate(t,r,n){return e.format(1024*(t.charCodeAt(0)-55296)+t.charCodeAt(1)-56320+65536,n.charCodeAt(r+2),e)}
/**
   * @param {string} character
   * @param {number} index
   * @param {string} all
   */function basic(t,r,n){return e.format(t.charCodeAt(0),n.charCodeAt(r+1),e)}}
/**
 * A wrapper function that caches the result of `charactersToExpression` with a WeakMap.
 * This can improve performance when tooling calls `charactersToExpression` repeatedly
 * with the same subset.
 *
 * @param {ReadonlyArray<string>} subset
 * @returns {RegExp}
 */function charactersToExpressionCached(t){let e=c.get(t);if(!e){e=charactersToExpression(t);c.set(t,e)}return e}
/**
 * @param {ReadonlyArray<string>} subset
 * @returns {RegExp}
 */function charactersToExpression(t){
/** @type {Array<string>} */
const e=[];let r=-1;while(++r<t.length)e.push(t[r].replace(s,"\\$&"));return new RegExp("(?:"+e.join("|")+")","g")}const i=/[\dA-Fa-f]/;
/**
 * Configurable ways to encode characters as hexadecimal references.
 *
 * @param {number} code
 * @param {number} next
 * @param {boolean|undefined} omit
 * @returns {string}
 */function toHexadecimal(t,e,r){const n="&#x"+t.toString(16).toUpperCase();return r&&e&&!i.test(String.fromCharCode(e))?n:n+";"}const a=/\d/;
/**
 * Configurable ways to encode characters as decimal references.
 *
 * @param {number} code
 * @param {number} next
 * @param {boolean|undefined} omit
 * @returns {string}
 */function toDecimal(t,e,r){const n="&#"+String(t);return r&&e&&!a.test(String.fromCharCode(e))?n:n+";"}
/**
 * List of legacy (that don’t need a trailing `;`) named references which could,
 * depending on what follows them, turn into a different meaning
 *
 * @type {Array<string>}
 */const u=["cent","copy","divide","gt","lt","not","para","times"];const f={}.hasOwnProperty;
/**
 * `characterEntitiesHtml4` but inverted.
 *
 * @type {Record<string, string>}
 */const l={};
/** @type {string} */let m;for(m in e)f.call(e,m)&&(l[e[m]]=m);const h=/[^\dA-Za-z]/;
/**
 * Configurable ways to encode characters as named references.
 *
 * @param {number} code
 * @param {number} next
 * @param {boolean|undefined} omit
 * @param {boolean|undefined} attribute
 * @returns {string}
 */function toNamed(e,r,n,o){const s=String.fromCharCode(e);if(f.call(l,s)){const e=l[s];const c="&"+e;return n&&t.includes(e)&&!u.includes(e)&&(!o||r&&r!==61&&h.test(String.fromCharCode(r)))?c:c+";"}return""}
/**
 * @typedef FormatSmartOptions
 * @property {boolean} [useNamedReferences=false]
 *   Prefer named character references (`&amp;`) where possible.
 * @property {boolean} [useShortestReferences=false]
 *   Prefer the shortest possible reference, if that results in less bytes.
 *   **Note**: `useNamedReferences` can be omitted when using `useShortestReferences`.
 * @property {boolean} [omitOptionalSemicolons=false]
 *   Whether to omit semicolons when possible.
 *   **Note**: This creates what HTML calls “parse errors” but is otherwise still valid HTML — don’t use this except when building a minifier.
 *   Omitting semicolons is possible for certain named and numeric references in some cases.
 * @property {boolean} [attribute=false]
 *   Create character references which don’t fail in attributes.
 *   **Note**: `attribute` only applies when operating dangerously with
 *   `omitOptionalSemicolons: true`.
 */
/**
 * Configurable ways to encode a character yielding pretty or small results.
 *
 * @param {number} code
 * @param {number} next
 * @param {FormatSmartOptions} options
 * @returns {string}
 */function formatSmart(t,e,r){let n=toHexadecimal(t,e,r.omitOptionalSemicolons);
/** @type {string|undefined} */let o;(r.useNamedReferences||r.useShortestReferences)&&(o=toNamed(t,e,r.omitOptionalSemicolons,r.attribute));if((r.useShortestReferences||!o)&&r.useShortestReferences){const o=toDecimal(t,e,r.omitOptionalSemicolons);o.length<n.length&&(n=o)}return o&&(!r.useShortestReferences||o.length<n.length)?o:n}
/**
 * The smallest way to encode a character.
 *
 * @param {number} code
 * @returns {string}
 */function formatBasic(t){return"&#x"+t.toString(16).toUpperCase()+";"}
/**
 * @typedef {import('./core.js').CoreOptions & import('./util/format-smart.js').FormatSmartOptions} Options
 * @typedef {import('./core.js').CoreOptions} LightOptions
 */
/**
 * Encode special characters in `value`.
 *
 * @param {string} value
 *   Value to encode.
 * @param {Options} [options]
 *   Configuration.
 * @returns {string}
 *   Encoded value.
 */function stringifyEntities(t,e){return core(t,Object.assign({format:formatSmart},e))}
/**
 * Encode special characters in `value` as hexadecimals.
 *
 * @param {string} value
 *   Value to encode.
 * @param {LightOptions} [options]
 *   Configuration.
 * @returns {string}
 *   Encoded value.
 */function stringifyEntitiesLight(t,e){return core(t,Object.assign({format:formatBasic},e))}
/**
 * @typedef {import('./lib/index.js').LightOptions} LightOptions
 * @typedef {import('./lib/index.js').Options} Options
 */export{stringifyEntities,stringifyEntitiesLight};

