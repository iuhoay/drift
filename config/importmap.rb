# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@rails/request.js", to: "@rails--request.js.js" # @0.0.13
pin "@shikijs/core", to: "@shikijs--core.js", preload: false # @4.3.1
# The JSPM entry references an internal relative chunk that importmap-rails does
# not vendor. Keep the browser-safe single-file ESM bundle under a custom name.
pin "@shikijs/engine-javascript", to: "shiki-engine-javascript.bundle.js", preload: false # @4.3.1
pin "@shikijs/langs/clojure", to: "@shikijs--langs--clojure.js", preload: false # @4.3.1
pin "@shikijs/langs/css", to: "@shikijs--langs--css.js", preload: false # @4.3.1
# These embedded-language grammars also need single-file bundles; their JSPM
# entries import sibling grammar files that are not copied by importmap-rails.
pin "@shikijs/langs/erb", to: "shiki-lang-erb.bundle.js", preload: false # @4.3.1
pin "@shikijs/langs/html", to: "shiki-lang-html.bundle.js", preload: false # @4.3.1
pin "@shikijs/langs/java", to: "@shikijs--langs--java.js", preload: false # @4.3.1
pin "@shikijs/langs/javascript", to: "@shikijs--langs--javascript.js", preload: false # @4.3.1
pin "@shikijs/langs/json", to: "@shikijs--langs--json.js", preload: false # @4.3.1
pin "@shikijs/langs/jsx", to: "@shikijs--langs--jsx.js", preload: false # @4.3.1
pin "@shikijs/langs/markdown", to: "@shikijs--langs--markdown.js", preload: false # @4.3.1
pin "@shikijs/langs/ruby", to: "shiki-lang-ruby.bundle.js", preload: false # @4.3.1
pin "@shikijs/langs/shellscript", to: "@shikijs--langs--shellscript.js", preload: false # @4.3.1
pin "@shikijs/langs/sql", to: "@shikijs--langs--sql.js", preload: false # @4.3.1
pin "@shikijs/langs/tsx", to: "@shikijs--langs--tsx.js", preload: false # @4.3.1
pin "@shikijs/langs/typescript", to: "@shikijs--langs--typescript.js", preload: false # @4.3.1
pin "@shikijs/langs/yaml", to: "@shikijs--langs--yaml.js", preload: false # @4.3.1
pin "@shikijs/primitive", to: "@shikijs--primitive.js", preload: false # @4.3.1
pin "@shikijs/types", to: "@shikijs--types.js", preload: false # @4.3.1
pin "@shikijs/vscode-textmate", to: "@shikijs--vscode-textmate.js", preload: false # @10.0.2
pin "ccount", preload: false # @2.0.1
pin "character-entities-html4", preload: false # @2.1.0
pin "character-entities-legacy", preload: false # @3.0.0
pin "comma-separated-tokens", preload: false # @2.0.3
pin "hast-util-to-html", preload: false # @9.0.5
pin "hast-util-whitespace", preload: false # @3.0.0
pin "html-void-elements", preload: false # @3.0.0
pin "property-information", preload: false # @7.2.0
pin "space-separated-tokens", preload: false # @2.0.2
pin "stringify-entities", preload: false # @4.0.4
pin "zwitch", preload: false # @2.0.4
