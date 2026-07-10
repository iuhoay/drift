// hast-util-whitespace@3.0.0 downloaded from https://ga.jspm.io/npm:hast-util-whitespace@3.0.0/index.js

/**
 * @typedef {import('hast').Nodes} Nodes
 */
const e=/[ \t\n\f\r]/g;
/**
 * Check if the given value is *inter-element whitespace*.
 *
 * @param {Nodes | string} thing
 *   Thing to check (`Node` or `string`).
 * @returns {boolean}
 *   Whether the `value` is inter-element whitespace (`boolean`): consisting of
 *   zero or more of space, tab (`\t`), line feed (`\n`), carriage return
 *   (`\r`), or form feed (`\f`); if a node is passed it must be a `Text` node,
 *   whose `value` field is checked.
 */function whitespace(e){return"object"===typeof e?"text"===e.type&&empty(e.value):empty(e)}
/**
 * @param {string} value
 * @returns {boolean}
 */function empty(t){return""===t.replace(e,"")}export{whitespace};

