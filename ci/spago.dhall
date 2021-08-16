{ name = "registry-ci"
, dependencies =
  [ "aff"
  , "aff-promise"
  , "affjax"
  , "argonaut"
  , "argonaut-core"
  , "arrays"
  , "bifunctors"
  , "bower-json"
  , "console"
  , "control"
  , "crypto"
  , "datetime"
  , "effect"
  , "either"
  , "foldable-traversable"
  , "foreign-object"
  , "functions"
  , "identity"
  , "js-date"
  , "lists"
  , "maybe"
  , "newtype"
  , "node-buffer"
  , "node-child-process"
  , "node-glob-basic"
  , "node-fs"
  , "node-fs-aff"
  , "node-path"
  , "node-process"
  , "now"
  , "nullable"
  , "ordered-collections"
  , "partial"
  , "prelude"
  , "psci-support"
  , "refs"
  , "safe-coerce"
  , "spec"
  , "string-parsers"
  , "strings"
  , "sunde"
  , "transformers"
  , "tuples"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}
