# Credo configuration as an overlay on the shipped defaults: `extra` tunes
# check params, `disabled` records deliberate style choices. Checks added by
# future Credo releases activate automatically (an explicit `enabled` list
# would freeze today's check set).
%{
  configs: [
    %{
      name: "default",
      checks: %{
        extra: [
          # One conditional inside a case is fine; default max_nesting 2 is too strict
          {Credo.Check.Refactor.Nesting, [max_nesting: 3]},
          # quantizer_test zero-pads numbers for column alignment, which this
          # check rejects (leading zeros); the padding is deliberate
          {Credo.Check.Readability.LargeNumbers,
           [files: %{excluded: ["test/asciinema/quantizer_test.exs"]}]}
        ],
        disabled: [
          # Occasional fully-qualified nested module calls are established style here
          {Credo.Check.Design.AliasUsage, []},
          # This codebase does not write @moduledoc; module/function names carry the intent
          {Credo.Check.Readability.ModuleDoc, []},
          # Explicit try/after around resource cleanup is established style here
          {Credo.Check.Readability.PreferImplicitTry, []},
          # Single-clause with/else (happy path first) is a pervasive idiom here
          {Credo.Check.Readability.WithSingleClause, []},
          # The offenders are pattern-match-heavy parsers/query builders (complexity
          # 10-33) that read fine; re-enable with grandfathering if a CI gate lands
          {Credo.Check.Refactor.CyclomaticComplexity, []}
        ]
      }
    }
  ]
}
