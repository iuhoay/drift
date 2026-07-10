// hast-util-to-html@9.0.5 downloaded from https://ga.jspm.io/npm:hast-util-to-html@9.0.5/index.js

import{htmlVoidElements as t}from"html-void-elements";import{svg as e,find as n,html as a}from"property-information";import{zwitch as o}from"zwitch";import{stringifyEntities as s}from"stringify-entities";import{ccount as r}from"ccount";import{stringify as i}from"comma-separated-tokens";import{stringify as l}from"space-separated-tokens";import{whitespace as c}from"hast-util-whitespace";const m=/^>|^->|<!--|-->|--!>|<!-$/g;const u=[">"];const g=["<",">"];
/**
 * Serialize a comment.
 *
 * @param {Comment} node
 *   Node to handle.
 * @param {number | undefined} _1
 *   Index of `node` in `parent.
 * @param {Parents | undefined} _2
 *   Parent of `node`.
 * @param {State} state
 *   Info passed around about the current state.
 * @returns {string}
 *   Serialized node.
 */function comment(t,e,n,a){return a.settings.bogusComments?"<?"+s(t.value,Object.assign({},a.settings.characterReferences,{subset:u}))+">":"\x3c!--"+t.value.replace(m,encode)+"--\x3e"
/**
   * @param {string} $0
   */;function encode(t){return s(t,Object.assign({},a.settings.characterReferences,{subset:g}))}}
/**
 * Serialize a doctype.
 *
 * @param {Doctype} _1
 *   Node to handle.
 * @param {number | undefined} _2
 *   Index of `node` in `parent.
 * @param {Parents | undefined} _3
 *   Parent of `node`.
 * @param {State} state
 *   Info passed around about the current state.
 * @returns {string}
 *   Serialized node.
 */function doctype(t,e,n,a){return"<!"+(a.settings.upperDoctype?"DOCTYPE":"doctype")+(a.settings.tightDoctype?"":" ")+"html>"}const f=siblings(1);const d=siblings(-1);
/** @type {Array<RootContent>} */const h=[];
/**
 * Factory to check siblings in a direction.
 *
 * @param {number} increment
 */function siblings(t){return sibling
/**
   * Find applicable siblings in a direction.
   *
   * @template {Parents} Parent
   *   Parent type.
   * @param {Parent | undefined} parent
   *   Parent.
   * @param {number | undefined} index
   *   Index of child in `parent`.
   * @param {boolean | undefined} [includeWhitespace=false]
   *   Whether to include whitespace (default: `false`).
   * @returns {Parent extends {children: Array<infer Child>} ? Child | undefined : never}
   *   Child of parent.
   */;function sibling(e,n,a){const o=e?e.children:h;let s=(n||0)+t;let r=o[s];if(!a)while(r&&c(r)){s+=t;r=o[s]}return r}}
/**
 * @callback OmitHandle
 *   Check if a tag can be omitted.
 * @param {Element} element
 *   Element to check.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether to omit a tag.
 *
 */const N={}.hasOwnProperty;
/**
 * Factory to check if a given node can have a tag omitted.
 *
 * @param {Record<string, OmitHandle>} handlers
 *   Omission handlers, where each key is a tag name, and each value is the
 *   corresponding handler.
 * @returns {OmitHandle}
 *   Whether to omit a tag of an element.
 */function omission(t){return omit
/**
   * Check if a given node can have a tag omitted.
   *
   * @type {OmitHandle}
   */;function omit(e,n,a){return N.call(t,e.tagName)&&t[e.tagName](e,n,a)}}const y=omission({body:body$1,caption:headOrColgroupOrCaption,colgroup:headOrColgroupOrCaption,dd:dd,dt:dt,head:headOrColgroupOrCaption,html:html$1,li:li,optgroup:optgroup,option:option,p:p,rp:rubyElement,rt:rubyElement,tbody:tbody$1,td:cells,tfoot:tfoot,th:cells,thead:thead,tr:tr});
/**
 * Macro for `</head>`, `</colgroup>`, and `</caption>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function headOrColgroupOrCaption(t,e,n){const a=f(n,e,true);return!a||a.type!=="comment"&&!(a.type==="text"&&c(a.value.charAt(0)))}
/**
 * Whether to omit `</html>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function html$1(t,e,n){const a=f(n,e);return!a||a.type!=="comment"}
/**
 * Whether to omit `</body>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function body$1(t,e,n){const a=f(n,e);return!a||a.type!=="comment"}
/**
 * Whether to omit `</p>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function p(t,e,n){const a=f(n,e);return a?a.type==="element"&&(a.tagName==="address"||a.tagName==="article"||a.tagName==="aside"||a.tagName==="blockquote"||a.tagName==="details"||a.tagName==="div"||a.tagName==="dl"||a.tagName==="fieldset"||a.tagName==="figcaption"||a.tagName==="figure"||a.tagName==="footer"||a.tagName==="form"||a.tagName==="h1"||a.tagName==="h2"||a.tagName==="h3"||a.tagName==="h4"||a.tagName==="h5"||a.tagName==="h6"||a.tagName==="header"||a.tagName==="hgroup"||a.tagName==="hr"||a.tagName==="main"||a.tagName==="menu"||a.tagName==="nav"||a.tagName==="ol"||a.tagName==="p"||a.tagName==="pre"||a.tagName==="section"||a.tagName==="table"||a.tagName==="ul"):!n||!(n.type==="element"&&(n.tagName==="a"||n.tagName==="audio"||n.tagName==="del"||n.tagName==="ins"||n.tagName==="map"||n.tagName==="noscript"||n.tagName==="video"))}
/**
 * Whether to omit `</li>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function li(t,e,n){const a=f(n,e);return!a||a.type==="element"&&a.tagName==="li"}
/**
 * Whether to omit `</dt>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function dt(t,e,n){const a=f(n,e);return Boolean(a&&a.type==="element"&&(a.tagName==="dt"||a.tagName==="dd"))}
/**
 * Whether to omit `</dd>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function dd(t,e,n){const a=f(n,e);return!a||a.type==="element"&&(a.tagName==="dt"||a.tagName==="dd")}
/**
 * Whether to omit `</rt>` or `</rp>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function rubyElement(t,e,n){const a=f(n,e);return!a||a.type==="element"&&(a.tagName==="rp"||a.tagName==="rt")}
/**
 * Whether to omit `</optgroup>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function optgroup(t,e,n){const a=f(n,e);return!a||a.type==="element"&&a.tagName==="optgroup"}
/**
 * Whether to omit `</option>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function option(t,e,n){const a=f(n,e);return!a||a.type==="element"&&(a.tagName==="option"||a.tagName==="optgroup")}
/**
 * Whether to omit `</thead>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function thead(t,e,n){const a=f(n,e);return Boolean(a&&a.type==="element"&&(a.tagName==="tbody"||a.tagName==="tfoot"))}
/**
 * Whether to omit `</tbody>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function tbody$1(t,e,n){const a=f(n,e);return!a||a.type==="element"&&(a.tagName==="tbody"||a.tagName==="tfoot")}
/**
 * Whether to omit `</tfoot>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function tfoot(t,e,n){return!f(n,e)}
/**
 * Whether to omit `</tr>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function tr(t,e,n){const a=f(n,e);return!a||a.type==="element"&&a.tagName==="tr"}
/**
 * Whether to omit `</td>` or `</th>`.
 *
 * @param {Element} _
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the closing tag can be omitted.
 */function cells(t,e,n){const a=f(n,e);return!a||a.type==="element"&&(a.tagName==="td"||a.tagName==="th")}const b=omission({body:body,colgroup:colgroup,head:head,html:html,tbody:tbody});
/**
 * Whether to omit `<html>`.
 *
 * @param {Element} node
 *   Element.
 * @returns {boolean}
 *   Whether the opening tag can be omitted.
 */function html(t){const e=f(t,-1);return!e||e.type!=="comment"}
/**
 * Whether to omit `<head>`.
 *
 * @param {Element} node
 *   Element.
 * @returns {boolean}
 *   Whether the opening tag can be omitted.
 */function head(t){
/** @type {Set<string>} */
const e=new Set;for(const n of t.children)if(n.type==="element"&&(n.tagName==="base"||n.tagName==="title")){if(e.has(n.tagName))return false;e.add(n.tagName)}const n=t.children[0];return!n||n.type==="element"}
/**
 * Whether to omit `<body>`.
 *
 * @param {Element} node
 *   Element.
 * @returns {boolean}
 *   Whether the opening tag can be omitted.
 */function body(t){const e=f(t,-1,true);return!e||e.type!=="comment"&&!(e.type==="text"&&c(e.value.charAt(0)))&&!(e.type==="element"&&(e.tagName==="meta"||e.tagName==="link"||e.tagName==="script"||e.tagName==="style"||e.tagName==="template"))}
/**
 * Whether to omit `<colgroup>`.
 * The spec describes some logic for the opening tag, but it’s easier to
 * implement in the closing tag, to the same effect, so we handle it there
 * instead.
 *
 * @param {Element} node
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the opening tag can be omitted.
 */function colgroup(t,e,n){const a=d(n,e);const o=f(t,-1,true);return!(n&&a&&a.type==="element"&&a.tagName==="colgroup"&&y(a,n.children.indexOf(a),n))&&Boolean(o&&o.type==="element"&&o.tagName==="col")}
/**
 * Whether to omit `<tbody>`.
 *
 * @param {Element} node
 *   Element.
 * @param {number | undefined} index
 *   Index of element in parent.
 * @param {Parents | undefined} parent
 *   Parent of element.
 * @returns {boolean}
 *   Whether the opening tag can be omitted.
 */function tbody(t,e,n){const a=d(n,e);const o=f(t,-1);return(!n||!a||a.type!=="element"||a.tagName!=="thead"&&a.tagName!=="tbody"||!y(a,n.children.indexOf(a),n))&&Boolean(o&&o.type==="element"&&o.tagName==="tr")}
/**
 * Maps of subsets.
 *
 * Each value is a matrix of tuples.
 * The value at `0` causes parse errors, the value at `1` is valid.
 * Of both, the value at `0` is unsafe, and the value at `1` is safe.
 *
 * @type {Record<'double' | 'name' | 'single' | 'unquoted', Array<[Array<string>, Array<string>]>>}
 */const v={name:[["\t\n\f\r &/=>".split(""),"\t\n\f\r \"&'/=>`".split("")],["\0\t\n\f\r \"&'/<=>".split(""),"\0\t\n\f\r \"&'/<=>`".split("")]],unquoted:[["\t\n\f\r &>".split(""),"\0\t\n\f\r \"&'<=>`".split("")],["\0\t\n\f\r \"&'<=>`".split(""),"\0\t\n\f\r \"&'<=>`".split("")]],single:[["&'".split(""),"\"&'`".split("")],["\0&'".split(""),"\0\"&'`".split("")]],double:[['"&'.split(""),"\"&'`".split("")],['\0"&'.split(""),"\0\"&'`".split("")]]};
/**
 * Serialize an element node.
 *
 * @param {Element} node
 *   Node to handle.
 * @param {number | undefined} index
 *   Index of `node` in `parent.
 * @param {Parents | undefined} parent
 *   Parent of `node`.
 * @param {State} state
 *   Info passed around about the current state.
 * @returns {string}
 *   Serialized node.
 */function element(t,n,a,o){const s=o.schema;const r=s.space!=="svg"&&o.settings.omitOptionalTags;let i=s.space==="svg"?o.settings.closeEmptyElements:o.settings.voids.includes(t.tagName.toLowerCase());
/** @type {Array<string>} */const l=[];
/** @type {string} */let c;s.space==="html"&&t.tagName==="svg"&&(o.schema=e);const m=serializeAttributes(o,t.properties);const u=o.all(s.space==="html"&&t.tagName==="template"?t.content:t);o.schema=s;u&&(i=false);if(m||!r||!b(t,n,a)){l.push("<",t.tagName,m?" "+m:"");if(i&&(s.space==="svg"||o.settings.closeSelfClosing)){c=m.charAt(m.length-1);(!o.settings.tightSelfClosing||c==="/"||c&&c!=='"'&&c!=="'")&&l.push(" ");l.push("/")}l.push(">")}l.push(u);i||r&&y(t,n,a)||l.push("</"+t.tagName+">");return l.join("")}
/**
 * @param {State} state
 * @param {Properties | null | undefined} properties
 * @returns {string}
 */function serializeAttributes(t,e){
/** @type {Array<string>} */
const n=[];let a=-1;
/** @type {string} */let o;if(e)for(o in e)if(e[o]!==null&&e[o]!==void 0){const a=serializeAttribute(t,o,e[o]);a&&n.push(a)}while(++a<n.length){const e=t.settings.tightAttributes?n[a].charAt(n[a].length-1):void 0;a!==n.length-1&&e!=='"'&&e!=="'"&&(n[a]+=" ")}return n.join("")}
/**
 * @param {State} state
 * @param {string} key
 * @param {Properties[keyof Properties]} value
 * @returns {string}
 */function serializeAttribute(t,e,a){const o=n(t.schema,e);const c=t.settings.allowParseErrors&&t.schema.space==="html"?0:1;const m=t.settings.allowDangerousCharacters?0:1;let u=t.quote;
/** @type {string | undefined} */let g;!o.overloadedBoolean||a!==o.attribute&&a!==""?!o.boolean&&!o.overloadedBoolean||typeof a==="string"&&a!==o.attribute&&a!==""||(a=Boolean(a)):a=true;if(a===null||a===void 0||a===false||typeof a==="number"&&Number.isNaN(a))return"";const f=s(o.attribute,Object.assign({},t.settings.characterReferences,{subset:v.name[c][m]}));if(a===true)return f;a=Array.isArray(a)?(o.commaSeparated?i:l)(a,{padLeft:!t.settings.tightCommaSeparatedLists}):String(a);if(t.settings.collapseEmptyAttributes&&!a)return f;t.settings.preferUnquoted&&(g=s(a,Object.assign({},t.settings.characterReferences,{attribute:true,subset:v.unquoted[c][m]})));if(g!==a){t.settings.quoteSmart&&r(a,u)>r(a,t.alternative)&&(u=t.alternative);g=u+s(a,Object.assign({},t.settings.characterReferences,{subset:(u==="'"?v.single:v.double)[c][m],attribute:true}))+u}return f+(g?"="+g:g)}const w=["<","&"];
/**
 * Serialize a text node.
 *
 * @param {Raw | Text} node
 *   Node to handle.
 * @param {number | undefined} _
 *   Index of `node` in `parent.
 * @param {Parents | undefined} parent
 *   Parent of `node`.
 * @param {State} state
 *   Info passed around about the current state.
 * @returns {string}
 *   Serialized node.
 */function text(t,e,n,a){return!n||n.type!=="element"||n.tagName!=="script"&&n.tagName!=="style"?s(t.value,Object.assign({},a.settings.characterReferences,{subset:w})):t.value}
/**
 * Serialize a raw node.
 *
 * @param {Raw} node
 *   Node to handle.
 * @param {number | undefined} index
 *   Index of `node` in `parent.
 * @param {Parents | undefined} parent
 *   Parent of `node`.
 * @param {State} state
 *   Info passed around about the current state.
 * @returns {string}
 *   Serialized node.
 */function raw(t,e,n,a){return a.settings.allowDangerousHtml?t.value:text(t,e,n,a)}
/**
 * Serialize a root.
 *
 * @param {Root} node
 *   Node to handle.
 * @param {number | undefined} _1
 *   Index of `node` in `parent.
 * @param {Parents | undefined} _2
 *   Parent of `node`.
 * @param {State} state
 *   Info passed around about the current state.
 * @returns {string}
 *   Serialized node.
 */function root(t,e,n,a){return a.all(t)}
/**
 * @type {(node: Nodes, index: number | undefined, parent: Parents | undefined, state: State) => string}
 */const C=o("type",{invalid:invalid,unknown:unknown,handlers:{comment:comment,doctype:doctype,element:element,raw:raw,root:root,text:text}});
/**
 * Fail when a non-node is found in the tree.
 *
 * @param {unknown} node
 *   Unknown value.
 * @returns {never}
 *   Never.
 */function invalid(t){throw new Error("Expected node, not `"+t+"`")}
/**
 * Fail when a node with an unknown type is found in the tree.
 *
 * @param {unknown} node_
 *  Unknown node.
 * @returns {never}
 *   Never.
 */function unknown(t){const e=/** @type {Nodes} */t;throw new Error("Cannot compile unknown node `"+e.type+"`")}
/** @type {Options} */const O={};
/** @type {CharacterReferences} */const E={};
/** @type {Array<never>} */const A=[];
/**
 * Serialize hast as HTML.
 *
 * @param {Array<RootContent> | Nodes} tree
 *   Tree to serialize.
 * @param {Options | null | undefined} [options]
 *   Configuration (optional).
 * @returns {string}
 *   Serialized HTML.
 */function toHtml(n,o){const s=o||O;const r=s.quote||'"';const i=r==='"'?"'":'"';if(r!=='"'&&r!=="'")throw new Error("Invalid quote `"+r+"`, expected `'` or `\"`");
/** @type {State} */const l={one:one,all:all,settings:{omitOptionalTags:s.omitOptionalTags||false,allowParseErrors:s.allowParseErrors||false,allowDangerousCharacters:s.allowDangerousCharacters||false,quoteSmart:s.quoteSmart||false,preferUnquoted:s.preferUnquoted||false,tightAttributes:s.tightAttributes||false,upperDoctype:s.upperDoctype||false,tightDoctype:s.tightDoctype||false,bogusComments:s.bogusComments||false,tightCommaSeparatedLists:s.tightCommaSeparatedLists||false,tightSelfClosing:s.tightSelfClosing||false,collapseEmptyAttributes:s.collapseEmptyAttributes||false,allowDangerousHtml:s.allowDangerousHtml||false,voids:s.voids||t,characterReferences:s.characterReferences||E,closeSelfClosing:s.closeSelfClosing||false,closeEmptyElements:s.closeEmptyElements||false},schema:s.space==="svg"?e:a,quote:r,alternative:i};return l.one(Array.isArray(n)?{type:"root",children:n}:n,void 0,void 0)}
/**
 * Serialize a node.
 *
 * @this {State}
 *   Info passed around about the current state.
 * @param {Nodes} node
 *   Node to handle.
 * @param {number | undefined} index
 *   Index of `node` in `parent.
 * @param {Parents | undefined} parent
 *   Parent of `node`.
 * @returns {string}
 *   Serialized node.
 */function one(t,e,n){return C(t,e,n,this)}
/**
 * Serialize all children of `parent`.
 *
 * @this {State}
 *   Info passed around about the current state.
 * @param {Parents | undefined} parent
 *   Parent whose children to serialize.
 * @returns {string}
 */function all(t){
/** @type {Array<string>} */
const e=[];const n=t&&t.children||A;let a=-1;while(++a<n.length)e[a]=this.one(n[a],a,t);return e.join("")}
/**
 * @typedef {import('./lib/index.js').CharacterReferences} CharacterReferences
 * @typedef {import('./lib/index.js').Options} Options
 * @typedef {import('./lib/index.js').Quote} Quote
 * @typedef {import('./lib/index.js').Space} Space
 */export{toHtml};

