# credo:disable-for-this-file Credo.Check.Readability.ModuleDoc

if Code.ensure_loaded?(Credo.Check) do
  defmodule Enviable.Credo.UnsafeAtom do
    use Credo.Check,
      id: "ENV001",
      base_priority: :high,
      category: :warning,
      explanations: [
        check: ~S"""
        Creating atoms from environment variables dynamically is a potentially unsafe
        because atoms are not garbage-collected by the runtime.

        Enviable functions that convert to atoms or modules should use the `:allowed`
        option to restrict which atoms can be created:

            Enviable.get_env_as_atom("VAR", allowed: [:foo, :bar])
            Enviable.fetch_env_as_module!("MODULE", allowed: [MyApp.Foo, MyApp.Bar])

        Or use the safe variants that only work with existing atoms:

            Enviable.get_env_as_safe_atom("VAR")
            Enviable.fetch_env_as_safe_module("MODULE")

        This also applies to generic conversion functions and encoded types:

            # Unsafe
            Enviable.get_env_as("VAR", :atom)
            Enviable.get_env_as("VAR", {:base64, :module})
            Enviable.get_env_as_list("ITEMS", as: :atom)

            # Safe alternatives
            Enviable.get_env_as("VAR", :safe_atom)
            Enviable.get_env_as("VAR", {:base64, :safe_module})
            Enviable.get_env_as_list("ITEMS", as: :safe_atom)

        When using `import Enviable`, the check applies to bare function calls:

            import Enviable

            # Unsafe
            get_env_as_atom("VAR")
            fetch_env_as_list!("ITEMS", as: :module)

            # Safe
            get_env_as_safe_atom("VAR")
            fetch_env_as_list!("ITEMS", as: :safe_module)

        This check can be configured to always warn even when using the `:allowed`
        option:

            {Enviable.Credo.UnsafeAtom, permit_with_allowed: false}
        """,
        params: [
          permit_with_allowed: "Allow unsafe functions if :allowed option is present"
        ]
      ],
      param_defaults: [permit_with_allowed: true]

    alias Credo.Check.Context
    alias Credo.Check.Params
    alias Credo.SourceFile

    @doc false
    @impl Credo.Check
    def run(%SourceFile{} = source_file, params) do
      ctx = Context.build(source_file, params, __MODULE__)
      permit_with_allowed = Params.get(params, :permit_with_allowed, __MODULE__)
      result = Credo.Code.prewalk(source_file, &walk(&1, &2, permit_with_allowed), ctx)
      result.issues
    end

    defp walk({{:., _meta1, [{:__aliases__, _, [:Enviable]}, fun]}, meta, args} = ast, ctx, permit_with_allowed) do
      case get_forbidden_call(fun, args, permit_with_allowed) do
        {bad, suggestion, trigger} ->
          {ast, put_issue(ctx, issue_for(ctx, meta, bad, suggestion, trigger))}

        nil ->
          {ast, ctx}
      end
    end

    defp walk({fun, meta, args} = ast, %{module_contains_import: true} = ctx, permit_with_allowed)
         when is_atom(fun) and is_list(args) do
      case get_forbidden_call(fun, args, permit_with_allowed) do
        {bad, suggestion, trigger} ->
          {ast, put_issue(ctx, issue_for(ctx, meta, bad, suggestion, trigger))}

        nil ->
          {ast, ctx}
      end
    end

    defp walk({:import, _, [{:__aliases__, _, [:Enviable]}]} = ast, ctx, _permit_with_allowed) do
      {ast, Map.put(ctx, :module_contains_import, true)}
    end

    defp walk(ast, ctx, _permit_with_allowed) do
      {ast, ctx}
    end

    @unsafe_atom [:get_env_as_atom, :fetch_env_as_atom, :fetch_env_as_atom!]

    # Direct unsafe functions
    defp get_forbidden_call(fun, args, permit_with_allowed) when fun in @unsafe_atom do
      check_allowed_option(
        args,
        permit_with_allowed,
        "Enviable.#{fun}",
        "use :allowed option or get_env_as_safe_atom",
        "Enviable.#{fun}"
      )
    end

    @unsafe_module [:get_env_as_module, :fetch_env_as_module, :fetch_env_as_module!]

    defp get_forbidden_call(fun, args, permit_with_allowed) when fun in @unsafe_module do
      check_allowed_option(
        args,
        permit_with_allowed,
        "Enviable.#{fun}",
        "use :allowed option or get_env_as_safe_module",
        "Enviable.#{fun}"
      )
    end

    @unsafe_generic [:get_env_as, :fetch_env_as, :fetch_env_as!]

    defp get_forbidden_call(fun, [_var, type | rest], permit_with_allowed)
         when fun in @unsafe_generic and type in [:atom, :module] do
      check_allowed_option(
        rest,
        permit_with_allowed,
        "Enviable.#{fun}(..., :#{type})",
        "use :allowed option or :safe_#{type}",
        "Enviable.#{fun}"
      )
    end

    defp get_forbidden_call(fun, [_var, {type_wrapper, type} | rest], permit_with_allowed)
         when fun in @unsafe_generic and type in [:atom, :module] do
      check_allowed_option(
        rest,
        permit_with_allowed,
        "Enviable.#{fun}(..., {#{inspect(type_wrapper)}, :#{type}})",
        "use :allowed option or :safe_#{type}",
        "Enviable.#{fun}"
      )
    end

    @unsafe_encoded [
      :get_env_as_base16,
      :get_env_as_base32,
      :get_env_as_base64,
      :get_env_as_url_base64,
      :get_env_as_hex32,
      :get_env_as_list,
      :fetch_env_as_base16,
      :fetch_env_as_base32,
      :fetch_env_as_base64,
      :fetch_env_as_url_base64,
      :fetch_env_as_hex32,
      :fetch_env_as_list,
      :fetch_env_as_base16!,
      :fetch_env_as_base32!,
      :fetch_env_as_base64!,
      :fetch_env_as_url_base64!,
      :fetch_env_as_hex32!,
      :fetch_env_as_list!
    ]

    # Encoded functions with as: :atom or as: :module
    defp get_forbidden_call(fun, args, permit_with_allowed) when fun in @unsafe_encoded do
      case has_unsafe_as_option(args) do
        {:unsafe, type} ->
          check_allowed_option(
            args,
            permit_with_allowed,
            "Enviable.#{fun}(..., as: :#{type})",
            "use :allowed option or as: :safe_#{type}",
            "Enviable.#{fun}"
          )

        nil ->
          nil
      end
    end

    defp get_forbidden_call(_fun, _args, _permit_with_allowed), do: nil

    defp has_unsafe_as_option(args) do
      Enum.find_value(args, fn
        opts when is_list(opts) ->
          case Keyword.get(opts, :as) do
            type when type in [:atom, :module] -> {:unsafe, type}
            _ -> nil
          end

        _ ->
          nil
      end)
    end

    defp check_allowed_option(args, true = _permit_with_allowed, bad, suggestion, trigger) do
      has_allowed =
        Enum.any?(args, fn
          opts when is_list(opts) -> Keyword.has_key?(opts, :allowed)
          _ -> false
        end)

      if !has_allowed, do: {bad, suggestion, trigger}
    end

    defp check_allowed_option(_args, false = _permit_with_allowed, bad, suggestion, trigger) do
      {bad, suggestion, trigger}
    end

    defp issue_for(ctx, meta, call, suggestion, trigger) do
      format_issue(ctx,
        message: "#{call} can cause atom exhaustion. Prefer to #{suggestion}.",
        trigger: trigger,
        line_no: meta[:line]
      )
    end
  end
end
