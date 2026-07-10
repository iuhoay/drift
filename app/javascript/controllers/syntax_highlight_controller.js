import { Controller } from "@hotwired/stimulus"

const DRIFT_THEME = {
  name: "drift-terminal",
  type: "dark",
  colors: {
    "editor.background": "var(--syntax-background)",
    "editor.foreground": "var(--syntax-foreground)"
  },
  settings: [
    {
      settings: {
        background: "var(--syntax-background)",
        foreground: "var(--syntax-foreground)"
      }
    },
    {
      scope: ["comment", "punctuation.definition.comment"],
      settings: { foreground: "var(--syntax-comment)", fontStyle: "italic" }
    },
    {
      scope: ["string", "string.quoted", "string.template", "markup.inserted"],
      settings: { foreground: "var(--syntax-string)" }
    },
    {
      scope: ["keyword", "storage", "storage.type", "storage.modifier"],
      settings: { foreground: "var(--syntax-keyword)" }
    },
    {
      scope: ["constant", "constant.numeric", "constant.language", "variable.language"],
      settings: { foreground: "var(--syntax-constant)" }
    },
    {
      scope: ["entity.name.function", "support.function", "meta.function-call", "variable.function"],
      settings: { foreground: "var(--syntax-function)" }
    },
    {
      scope: ["entity.name.type", "entity.name.class", "support.type", "support.class"],
      settings: { foreground: "var(--syntax-type)" }
    },
    {
      scope: ["entity.name.tag", "punctuation.definition.tag", "meta.tag"],
      settings: { foreground: "var(--syntax-tag)" }
    },
    {
      scope: ["entity.other.attribute-name", "variable.other.property"],
      settings: { foreground: "var(--syntax-property)" }
    },
    {
      scope: ["keyword.operator", "punctuation", "meta.brace"],
      settings: { foreground: "var(--syntax-punctuation)" }
    },
    {
      scope: ["invalid", "invalid.illegal"],
      settings: { foreground: "var(--syntax-invalid)" }
    }
  ]
}

const LANGUAGE_ALIASES = {
  bash: "shellscript",
  clj: "clojure",
  clojure: "clojure",
  css: "css",
  erb: "erb",
  html: "html",
  java: "java",
  javascript: "javascript",
  js: "javascript",
  jsx: "jsx",
  json: "json",
  jsonc: "json",
  markdown: "markdown",
  md: "markdown",
  rb: "ruby",
  ruby: "ruby",
  sh: "shellscript",
  shell: "shellscript",
  shellscript: "shellscript",
  sql: "sql",
  ts: "typescript",
  tsx: "tsx",
  typescript: "typescript",
  xml: "html",
  yaml: "yaml",
  yml: "yaml"
}

const LANGUAGE_LABELS = {
  clojure: "Clojure",
  css: "CSS",
  erb: "ERB",
  html: "HTML",
  java: "Java",
  javascript: "JavaScript",
  json: "JSON",
  jsx: "JSX",
  markdown: "Markdown",
  ruby: "Ruby",
  shellscript: "Shell",
  sql: "SQL",
  tsx: "TSX",
  typescript: "TypeScript",
  yaml: "YAML"
}

const LANGUAGE_LOADERS = {
  clojure: () => import("@shikijs/langs/clojure"),
  css: () => import("@shikijs/langs/css"),
  erb: () => import("@shikijs/langs/erb"),
  html: () => import("@shikijs/langs/html"),
  java: () => import("@shikijs/langs/java"),
  javascript: () => import("@shikijs/langs/javascript"),
  json: () => import("@shikijs/langs/json"),
  jsx: () => import("@shikijs/langs/jsx"),
  markdown: () => import("@shikijs/langs/markdown"),
  ruby: () => import("@shikijs/langs/ruby"),
  shellscript: () => import("@shikijs/langs/shellscript"),
  sql: () => import("@shikijs/langs/sql"),
  tsx: () => import("@shikijs/langs/tsx"),
  typescript: () => import("@shikijs/langs/typescript"),
  yaml: () => import("@shikijs/langs/yaml")
}

let highlighterPromise
const languagePromises = new Map()

async function highlighter() {
  if (!highlighterPromise) {
    highlighterPromise = Promise.all([
      import("@shikijs/core"),
      import("@shikijs/engine-javascript")
    ]).then(([{ createHighlighterCore }, { createJavaScriptRegexEngine }]) =>
      createHighlighterCore({
        themes: [DRIFT_THEME],
        langs: [],
        engine: createJavaScriptRegexEngine()
      })
    )
  }

  return highlighterPromise
}

async function loadLanguage(instance, language) {
  if (!languagePromises.has(language)) {
    const promise = instance.loadLanguage(LANGUAGE_LOADERS[language]())
      .catch((error) => {
        languagePromises.delete(language)
        throw error
      })
    languagePromises.set(language, promise)
  }

  return languagePromises.get(language)
}

function languageHint(pre, code) {
  const hints = [
    code.dataset.language,
    code.dataset.lang,
    pre.dataset.language,
    pre.dataset.lang,
    ...code.classList,
    ...pre.classList
  ].filter(Boolean)

  for (const hint of hints) {
    const normalized = hint.toLowerCase().replace(/^(?:language|lang)-/, "")
    if (LANGUAGE_ALIASES[normalized]) return LANGUAGE_ALIASES[normalized]
  }
}

export default class extends Controller {
  connect() {
    this.connected = true
    const blocks = [...this.element.querySelectorAll("pre > code")]
      .map((code) => ({ code, pre: code.parentElement, language: languageHint(code.parentElement, code) }))
      .filter(({ pre, code, language }) => language && code.textContent.trim() && !pre.dataset.shikiHighlighted)

    if (blocks.length > 0) this.highlight(blocks)
  }

  disconnect() {
    this.connected = false
  }

  async highlight(blocks) {
    try {
      const instance = await highlighter()
      await Promise.all([...new Set(blocks.map(({ language }) => language))]
        .map((language) => loadLanguage(instance, language)))

      if (!this.connected) return

      for (const { pre, code, language } of blocks) {
        const template = document.createElement("template")
        template.innerHTML = instance.codeToHtml(code.textContent, {
          lang: language,
          theme: DRIFT_THEME.name
        })

        const renderedPre = template.content.firstElementChild
        const renderedCode = renderedPre.querySelector("code")

        code.replaceChildren(...renderedCode.childNodes)
        pre.classList.add(...renderedPre.classList)
        pre.style.cssText = renderedPre.style.cssText
        pre.tabIndex = 0
        pre.dataset.languageLabel = LANGUAGE_LABELS[language]
        pre.dataset.shikiHighlighted = "true"
      }
    } catch (error) {
      console.warn("Drift could not highlight this entry's code blocks", error)
    }
  }
}
