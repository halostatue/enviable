# Used by "mix format"
[
  import_deps: [:nimble_parsec],
  inputs: ["{mix,.formatter,.credo}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  plugins: [Quokka]
]
