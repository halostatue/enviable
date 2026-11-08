defmodule Enviable.Conversion.Schema do
  @moduledoc false

  # NimbleOptions schemas for every conversion type.
  #
  # Each schema is defined here with its documentation and used for three things:
  #
  # - validation (Enviable.Conversion.Config.parse/2)
  # - generated `### Options` documentation (docs/2)
  # - generated option typespecs (option_typespec/1)
  #
  # A schema describes the *shape* of each option. Cross-key constraints (`downcase`
  # vs `upcase`, `truthy` vs `falsy`, `default` in `allowed`), value preparation (default
  # coercion, `allowed` lookup tables), and compile-time configuration defaults
  # (`:boolean_downcase`) belong to Enviable.Conversion.Config.
  #
  # Option values are suppressed from error messages as they may leak secret values.
  #
  # `type_plain:` is a pseudo-key for used in the schema definition to describe the plain
  # text type description for error messages. Like `type_doc:`, it defaults to
  # a description of `type:` and is overridden where the NimbleOptions type is broader
  # than the documented type (`:module` options are `:atom` to NimbleOptions).

  alias Enviable.Conversion.Schema.TypeDoc
  alias Enviable.Conversion.Schema.TypeSpec

  has_decimal? = Code.ensure_loaded?(Decimal)

  @log_levels [:emergency, :alert, :critical, :error, :warning, :warn, :notice, :info, :debug, :all, :none]

  decimal_primitive = if has_decimal?, do: [:decimal], else: []

  @primitives [
    :atom,
    :boolean,
    :charlist,
    :duration,
    :elixir,
    :erlang,
    :float,
    :integer,
    :json,
    :log_level,
    :module,
    :pem,
    :safe_atom,
    :safe_module,
    :string,
    :timeout | decimal_primitive
  ]

  @encodings [:base16, :base32, :hex32, :base64, :url_base64, :list]

  # Element types that cannot be reliably split from a delimited list.
  @unlisted [:elixir, :erlang, :json, :pem]

  atom_exhaustion =
    "[Preventing atom exhaustion](https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/atom_exhaustion)"

  casefold = [type: {:or, [:boolean, {:in, [:default, :ascii, :greek, :turkic]}]}]

  casefold_doc = fn fun ->
    """
    Case folding mode passed to `String.#{fun}/2`. `true` has the same meaning as
    `:default`.
    """
  end

  atom_schema = [
    allowed: [
      type: {:list, :atom},
      doc: """
      Permitted atoms used as a lookup table. Any value not found in this list results in
      an exception. Strongly recommended for untrusted input; see #{atom_exhaustion}.
      """
    ],
    default: [
      type: {:or, [:atom, :string]},
      doc: """
      The atom to use if the variable is unset. If `:allowed` is present, the default must
      be one of the permitted values.
      """
    ],
    downcase: [{:doc, casefold_doc.("downcase") <> " Mutually exclusive with `:upcase`."} | casefold],
    upcase: [{:doc, casefold_doc.("upcase") <> " Mutually exclusive with `:downcase`."} | casefold]
  ]

  module_schema = [
    allowed: [
      type: {:list, :atom},
      type_doc: "a list of `t:module/0`",
      type_plain: "a list of modules",
      type_spec: quote(do: [module()]),
      doc: """
      Permitted modules used as a lookup table. Any value not found in this list results
      in an exception. Strongly recommended for untrusted input; see #{atom_exhaustion}.
      """
    ],
    default: [
      type: {:or, [:atom, :string]},
      type_doc: "`t:module/0` or `t:String.t/0`",
      type_plain: "module or string",
      type_spec: quote(do: module() | String.t()),
      doc: """
      The module to use if the variable is unset. If `:allowed` is present, the default
      must be one of the permitted values.
      """
    ]
  ]

  encoding_case = fn fun ->
    [
      type: {:in, [:lower, :mixed, :upper]},
      default: :mixed,
      doc: "The `:case` passed to `Base.#{fun}/2`."
    ]
  end

  padding = fn fun ->
    [
      type: :boolean,
      default: false,
      doc: """
      Whether padding is required (the `:padding` passed to `Base.#{fun}/2`). Enviable's
      default is more permissive than `Base`, which requires padding.
      """
    ]
  end

  ignore_whitespace = [
    type: :boolean,
    default: true,
    doc: """
    Whether whitespace is ignored when decoding. Enviable's default is more permissive
    than `Base.decode64/2` and `Base.url_decode64/2`, which reject whitespace.
    """
  ]

  decimal_json = if has_decimal?, do: [{:struct, Decimal}], else: []

  json_default_types = [
    :string,
    :boolean,
    :integer,
    :float,
    nil,
    {:list, :any},
    {:map, :string, :any} | decimal_json
  ]

  definitions = %{
    atom: atom_schema,
    safe_atom: atom_schema,
    module: module_schema,
    safe_module: module_schema,
    boolean: [
      default: [
        type: :boolean,
        doc: """
        The value to use if the variable is unset. The default is `false`.

        Use `true` for a feature that must be turned off explicitly.
        """
      ],
      downcase:
        casefold ++
          [
            doc: """
            #{casefold_doc.("downcase")} The default is `:default`, which may be changed
            at compile time through application configuration:

            ```elixir
            config :enviable, :boolean_downcase, true
            config :enviable, :boolean_downcase, :default
            config :enviable, :boolean_downcase, :ascii
            ```
            """
          ],
      truthy: [
        type: {:list, :string},
        doc: """
        Values that convert to `true`; any other value is `false`. Cannot be provided with
        `:falsy`. If neither is provided, the default is `truthy: ~w[1 true]`.
        """
      ],
      falsy: [
        type: {:list, :string},
        doc: """
        Values that convert to `false`; any other value is `true`. Cannot be provided with
        `:truthy`. Usually combined with `default: true`.
        """
      ],
      then: [
        type: :any,
        type_doc: "`t:term/0`",
        type_plain: "any term",
        type_spec: quote(do: term()),
        doc: """
        The value returned when the computed boolean is `true`. Must be provided with
        `:else`.
        """
      ],
      else: [
        type: :any,
        type_doc: "`t:term/0`",
        type_plain: "any term",
        type_spec: quote(do: term()),
        doc: """
        The value returned when the computed boolean is `false`. Must be provided with
        `:then`.
        """
      ]
    ],
    charlist: [
      default: [
        type: {:or, [:string, {:list, :integer}]},
        type_doc: "`t:String.t/0` or `t:charlist/0`",
        type_plain: "string or charlist",
        type_spec: quote(do: String.t() | charlist()),
        doc: "The value to use if the variable is unset."
      ]
    ],
    duration: [
      default: [
        type: {:or, [{:struct, Duration}, :string]},
        doc: """
        The value to use if the variable is unset. Strings must be parseable by
        `Duration.from_iso8601/1`.
        """
      ]
    ],
    float: [
      default: [
        type: {:or, [:float, :integer, :string]},
        doc: """
        The value to use if the variable is unset. Integers are converted to float;
        strings must parse cleanly as float.
        """
      ]
    ],
    integer: [
      base: [type: {:in, 2..36}, default: 10, doc: "The base for integer conversion."],
      default: [
        type: {:or, [:integer, :string]},
        doc: """
        The value to use if the variable is unset. Strings must be expressed in `:base`
        and convert cleanly to an integer.
        """
      ]
    ],
    json: [
      default: [
        type: {:or, json_default_types},
        type_doc: "`t:Enviable.Conversion.json/0`",
        type_plain: "a JSON value",
        type_spec: quote(do: Enviable.Conversion.json()),
        doc: "The value to use if the variable is unset."
      ],
      engine: [
        type: {:or, [:atom, {:fun, 1}, {:tuple, [:atom, :atom, {:list, :any}]}]},
        type_doc: """
        `t:module/0`, a function of arity 1, or a `{module, function, args}` tuple
        """,
        type_plain: "module, a function of arity 1, or a {module, function, args} tuple",
        type_spec: quote(do: module() | (String.t() -> term()) | {module(), atom(), list()}),
        doc: """
        The JSON engine to use: a module that exports `decode/1`, an arity 1 function, or
        a `{module, function, args}` tuple (the value is passed as the first argument). If
        the engine returns `{:ok, json}` or a JSON value, the conversion succeeds; any
        other result is a failure.

        The default is selected from the `:enviable` application configuration option
        `:json_engine`. If this is unset, the default is the first available of:

        - [`JSON`](https://hexdocs.pm/elixir/JSON.html) if the Elixir `m:JSON` module is
          available (Elixir 1.18+)
        - `:json` if the Erlang/OTP 27+ `m::json` module is available or if
          [json_polyfill](https://hexdocs.pm/json_polyfill/readme.html) is installed
        - [Jason](https://hexdocs.pm/jason/readme.html)

        This example uses [Thoas](https://hexdocs.pm/thoas/readme.html) as the JSON
        engine:

        ```elixir
        import Config

        config :enviable, :json_engine, :thoas
        ```
        """
      ]
    ],
    log_level: [
      default: [
        type: {:or, [{:in, @log_levels}, :string]},
        type_doc: "`t:Enviable.Conversion.log_level/0` or `t:String.t/0`",
        type_plain: "log level or string",
        type_spec: quote(do: Enviable.Conversion.log_level() | String.t()),
        doc: "The value to use if the variable is unset. Must be a valid log level."
      ]
    ],
    pem: [
      filter: [
        type: {:or, [:boolean, {:in, [:cert, :key]}]},
        default: true,
        doc: """
        Filters the output of `:public_key.pem_decode/1`:

        - `false`: the list is returned without processing, suitable for further
          processing with `:public_key.pem_entry_decode/2`.
        - `true`: returns the first unencrypted `:PrivateKeyInfo` found, a list of
          unencrypted `:Certificate` records, or an empty list.
        - `:cert`: returns a list of unencrypted `:Certificate` records or raises an
          exception if none are found.
        - `:key`: returns the first unencrypted `:PrivateKeyInfo` record or raises an
          exception if one is not found.
        """
      ]
    ],
    timeout: [
      default: [
        type:
          {:or,
           [
             {:in, [:infinity]},
             :non_neg_integer,
             {:struct, Duration},
             :string,
             {:keyword_list, Enum.map(~w[week day hour minute second millisecond]a, &{&1, [type: :non_neg_integer]})}
           ]},
        type_doc: "`t:Enviable.Conversion.timeout_default/0`",
        type_plain: "timeout, Duration, string, or keyword list of time units",
        type_spec: quote(do: Enviable.Conversion.timeout_default()),
        doc: """
        The value to use if the variable is unset: a timeout string, a `t:Duration.t/0`,
        a `t:timeout/0`, or a keyword list as accepted by `Kernel.to_timeout/1`. The
        default is `:infinity`.
        """
      ]
    ],
    elixir: [],
    erlang: [],
    base16: [case: encoding_case.("decode16")],
    base32: [case: encoding_case.("decode32"), padding: padding.("decode32")],
    hex32: [case: encoding_case.("hex_decode32"), padding: padding.("hex_decode32")],
    base64: [ignore_whitespace: ignore_whitespace, padding: padding.("decode64")],
    url_base64: [ignore_whitespace: ignore_whitespace, padding: padding.("url_decode64")],
    list: [
      default: [
        type: {:or, [:string, {:list, :any}]},
        type_spec: quote(do: String.t() | list()),
        doc: """
        The value to use if the variable is unset. A string is split and converted as if
        it were the value. A list of strings is converted element by element with the
        remaining options. Any other list must contain values acceptable as `:default` for
        the element type (`:as`); each is prepared as that type's default.
        """
      ],
      delimiter: [
        type:
          {:or,
           [
             :string,
             {:list, :string},
             {:struct, Regex},
             {:custom, __MODULE__, :__compiled_pattern__, []}
           ]},
        default: ",",
        type_doc: "`t:String.pattern/0` or `t:Regex.t/0`",
        type_plain: "string pattern or regular expression",
        type_spec: quote(do: String.pattern() | Regex.t()),
        doc: """
        The delimiter used to separate list entries: a string, a list of strings,
        a compiled pattern from `:binary.compile_pattern/1`, or a regular expression, as
        accepted by `String.split/3`.
        """
      ],
      parts: [
        type: {:or, [{:in, [:infinity]}, :pos_integer]},
        doc: "The maximum number of parts to split into. Passed to `String.split/3`."
      ],
      trim: [type: :boolean, doc: "Whether empty entries are omitted."],
      on: [
        type:
          {:or,
           [
             {:in, [:all, :first, :all_but_first, :none, :all_names]},
             {:list, {:or, [:string, :atom]}}
           ]},
        type_doc: """
        one of `:all`, `:first`, `:all_but_first`, `:none`, `:all_names`, or a list of
        capture names (`t:String.t/0` or `t:atom/0`)
        """,
        type_plain: """
        one of :all, :first, :all_but_first, :none, :all_names, or a list of capture names\
        """,
        doc: """
        Regular expression delimiters only. Which captures to split the string on, and in
        what order. The default is `:first`, which means captures inside the regular
        expression do not affect splitting. See `Regex.split/3`.
        """
      ],
      include_captures: [
        type: :boolean,
        doc: """
        Regular expression delimiters only. Whether the matches of the regular expression
        are included in the result. The matches are not counted towards `:parts`. The
        default is `false`.
        """
      ]
    ],
    string: [
      default: [
        type: :string,
        doc: "The value to use if the variable is unset."
      ]
    ]
  }

  definitions =
    if has_decimal? do
      Map.put(definitions, :decimal,
        default: [
          type: {:or, [{:struct, Decimal}, :float, :integer, :string]},
          type_spec: quote(do: Decimal.t() | float() | integer() | String.t()),
          doc: """
          The value to use if the variable is unset. Floats, integers, and strings must
          convert cleanly to `t:Decimal.t/0`.
          """
        ]
      )
    else
      definitions
    end

  # `:or_raise` is a universal option on every conversion layer: when the variable is
  # unset, an exception is raised with the provided message instead of returning `nil`,
  # the type's default, or applying `:default`. Mutually exclusive with `:default` (checked
  # in Enviable.Conversion.Config).
  or_raise =
    [
      {:or_raise,
       [
         type: :string,
         doc: """
          A message used to raise an exception when the variable is unset, instead of
            returning `nil` or the `:default`. Cannot be provided with `:default`.
         """
       ]}
    ]

  definitions = Map.new(definitions, fn {type, entries} -> {type, entries ++ or_raise} end)

  as_spec = fn
    :list ->
      [
        type: {:in, @primitives},
        type_doc: "`t:Enviable.Conversion.primitive/0`",
        type_plain: "a primitive conversion",
        type_spec: quote(do: Enviable.Conversion.primitive()),
        doc: """
        The type that each list entry is converted to. The default is `:string`.
        `{:list, type}` is the same as `:list` with `as: type`. Options for that type may
        also be provided, except `:default` (which applies to the whole list).
        """
      ]

    :encoded ->
      [
        type: {:in, @primitives},
        type_doc: "`t:Enviable.Conversion.primitive/0`",
        type_plain: "a primitive conversion",
        type_spec: quote(do: Enviable.Conversion.primitive()),
        doc: """
        The type that the decoded value is converted to. The default is `:string`.
        `{encoding, type}` is the same as `encoding` with `as: type`. Options for that type
        may also be provided.
        """
      ]
  end

  encoded_default = fn encoding ->
    [
      type: :any,
      type_doc: "a `:default` for the `:as` type",
      doc: """
      The value to use if the variable is unset. This is the *decoded* result, not an
      encoded string: a value accepted as `:default` by the `:as` type (`:string`, if
      `:as` is not provided). For example, `"30s"` is a valid default for
      `{:#{encoding}, :timeout}`.
      """
    ]
  end

  # NimbleOptions puts the first line of each doc on the option's bullet line, so a
  # hard-wrapped paragraph renders with one long line followed by short ones. Prose
  # paragraphs are unwrapped; lists and code blocks are left alone.
  unwrap = fn doc ->
    doc
    |> String.split("\n\n")
    |> Enum.map_join("\n\n", fn paragraph ->
      lines = String.split(paragraph, "\n")

      if Enum.any?(lines, &String.match?(&1, ~r/^\s*(- |\* |```|\d+\. )|^\s{2,}/)) do
        paragraph
      else
        Enum.join(lines, " ")
      end
    end)
  end

  finish = fn entries ->
    Enum.map(entries, fn {key, spec} ->
      type = Keyword.fetch!(spec, :type)

      spec =
        spec
        |> Keyword.update!(:doc, &unwrap.(String.trim(&1)))
        |> Keyword.put_new(:type_doc, TypeDoc.describe(type, :markdown))
        |> Keyword.put_new(:type_plain, TypeDoc.describe(type, :plain))
        |> Keyword.put_new(:type_spec, TypeSpec.quoted(type))

      {key, spec}
    end)
  end

  documented = Map.new(definitions, fn {type, entries} -> {type, finish.(entries)} end)

  @type_plain Map.new(documented, fn {type, entries} ->
                {type, Map.new(entries, fn {key, spec} -> {key, spec[:type_plain]} end)}
              end)

  @documented Map.new(documented, fn {type, entries} ->
                {type, Enum.map(entries, fn {key, spec} -> {key, Keyword.delete(spec, :type_plain)} end)}
              end)

  @as_list Enum.map(finish.(as: as_spec.(:list)), fn {k, spec} -> {k, Keyword.delete(spec, :type_plain)} end)
  @as_encoded Enum.map(finish.(as: as_spec.(:encoded)), fn {k, spec} -> {k, Keyword.delete(spec, :type_plain)} end)
  @encoded_default Map.new(@encodings -- [:list], fn encoding ->
                     [{:default, spec}] = finish.(default: encoded_default.(encoding))
                     {encoding, [default: Keyword.delete(spec, :type_plain)]}
                   end)

  @schemas Map.new(@documented, fn {type, entries} -> {type, NimbleOptions.new!(entries)} end)

  # These functions are called only while compiling other modules (module attributes,
  # `@doc` interpolation, and `@spec`/`@type` unquoting), so they are never executed under
  # test coverage.

  # All supported primitive conversion types.
  @spec primitives :: [atom()]
  def primitives, do: @primitives

  # All supported encoded conversion types.
  @spec encodings :: [atom()]
  def encodings, do: @encodings

  # Primitive types that may not be used as list elements.
  @spec unlisted :: [atom()]
  def unlisted, do: @unlisted

  # Returns the `### Options` documentation for a single conversion layer.
  #
  # Options:
  # - `:except`: option keys to leave out of the documentation.
  # - `:as`: adds documentation for the wrapper `:as` option (`:list` or `:encoded`).
  @spec docs(atom(), keyword()) :: String.t()
  def docs(type, opts \\ []) do
    except = Keyword.get(opts, :except, [])

    as =
      case Keyword.get(opts, :as) do
        nil -> []
        :list -> @as_list
        :encoded -> @as_encoded
      end

    entries = Map.get(@encoded_default, type, []) ++ Map.fetch!(@documented, type)
    entries = Keyword.drop(as ++ entries, except)

    case entries do
      [] -> "This conversion has no options."
      entries -> NimbleOptions.docs(entries)
    end
  end

  # Returns the quoted option typespec for a single conversion layer: a union of
  # `{key, type}` tuples. Must be used with `unquote/1` in a typespec.
  #
  # Options:
  # - `:only`: option keys to include (all, if not provided).
  # - `:except`: option keys to leave out.
  # - `:as`: adds the wrapper `:as` option (`:list` or `:encoded`), the `:default` for
  #   encoded conversions, and `{atom(), term()}` for options of the `:as` type.
  @spec option_typespec(atom(), keyword()) :: Macro.t()
  def option_typespec(type, opts \\ []) do
    except = Keyword.get(opts, :except, [])
    entries = Map.fetch!(@documented, type)
    entries = if only = opts[:only], do: Keyword.take(entries, only), else: entries

    specs =
      entries
      |> Keyword.drop(except)
      |> Enum.map(fn {key, spec} -> {key, Keyword.fetch!(spec, :type_spec)} end)

    specs =
      case Keyword.get(opts, :as) do
        nil ->
          specs

        as ->
          as_spec = {:as, quote(do: Enviable.Conversion.primitive())}
          encoded_default = if as == :encoded and :default not in except, do: [{:default, quote(do: term())}], else: []
          [as_spec | encoded_default] ++ specs ++ [quote(do: {atom(), term()})]
      end

    TypeSpec.union(specs)
  end

  # Returns the compiled schema for a single conversion layer.
  @spec schema(atom()) :: NimbleOptions.t()
  def schema(type), do: Map.fetch!(@schemas, type)

  # Returns the option keys accepted by a single conversion layer.
  @spec keys(atom()) :: [atom()]
  def keys(type) do
    @documented
    |> Map.fetch!(type)
    |> Keyword.keys()
  end

  # Validates options for a single conversion layer. Unknown options are rejected. `opts`
  # must be a keyword list (Enviable.Conversion checks this before calling).
  #
  # On failure, returns the failing option key and a reason that never includes option
  # values.
  @spec validate(atom(), keyword()) :: {:ok, keyword()} | {:error, atom() | [atom()], String.t()}
  def validate(type, opts) do
    with :ok <- check_unknown(type, opts) do
      case NimbleOptions.validate(opts, schema(type)) do
        {:ok, validated} -> {:ok, validated}
        {:error, %NimbleOptions.ValidationError{} = error} -> error_reason(type, error)
      end
    end
  end

  defp check_unknown(type, opts) do
    known = keys(type)

    unknown =
      opts
      |> Keyword.keys()
      |> Enum.uniq()
      |> Enum.reject(&(&1 in known))

    case unknown do
      [] -> :ok
      unknown -> {:error, unknown, unknown_reason(unknown, known)}
    end
  end

  @doc false
  @spec unknown_reason([atom()], [atom()]) :: String.t()
  # Every conversion type has `:or_raise`. `known` shouldn't be empty, but safety first.
  def unknown_reason(unknown, []) do
    "#{unknown_noun(unknown)} #{format_keys(unknown)} (no options are supported)"
  end

  def unknown_reason(unknown, known) do
    "#{unknown_noun(unknown)} #{format_keys(unknown)} (supported: #{format_keys(known)})"
  end

  defp unknown_noun([_]), do: "unknown option"
  defp unknown_noun(_), do: "unknown options"

  defp format_keys(keys), do: Enum.map_join(keys, ", ", &"`#{inspect(&1)}`")

  # Customize the messages from validation failure to hide explicit values.
  defp error_reason(type, %NimbleOptions.ValidationError{key: key, keys_path: keys_path}) do
    top = List.first(keys_path, key)

    expected =
      @type_plain
      |> Map.fetch!(type)
      |> Map.fetch!(top)

    {:error, top, "invalid `#{inspect(top)}` value (expected #{expected})"}
  end

  @doc false
  def __compiled_pattern__(pattern) do
    if is_tuple(pattern) do
      {:ok, pattern}
    else
      {:error, "expected a compiled pattern from :binary.compile_pattern/1"}
    end
  end
end
