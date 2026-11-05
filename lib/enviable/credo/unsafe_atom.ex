# credo:disable-for-this-file Credo.Check.Readability.ModuleDoc

if Code.ensure_loaded?(Credo.Check) do
  # coveralls-ignore-next-line
  defmodule Enviable.Credo.UnsafeAtom do
    use Credo.Check,
      id: "ENV001",
      base_priority: :high,
      category: :warning,
      explanations: [
        check: ~S"""
        Creating atoms from environment variables dynamically is considered unsafe
        because atoms are not garbage-collected by the runtime.

        Enviable and Enviable.Codex functions that convert to atoms or modules
        should use the `:allowed` option to restrict which atoms can be created or
        use the safe_ variants that only work with existing atoms. This applies to
        both the named and generic conversion functions and encoded types:

            alias Envible.Codex

            Enviable.get_env_as_atom("VAR", allowed: [:foo, :bar])
            Codex.get_env("VAR") |> Codex.as_atom(allowed: [:foo, :bar])

            Enviable.get_env_as_safe_atom("VAR")
            Enviable.get_env_as("VAR", {:base64, :safe_atom})
            Codex.get_env("VAR"0 |> Codex.as({:base64, :safe_module})

        When either Enviable or Enviable.Codex are imported, the check applies to
        bare function calls:

            import Enviable

            # Unsafe
            get_env_as_atom("VAR")
            fetch_env_as_list!("ITEMS", as: :module)

            # Safe
            get_env_as_safe_atom("VAR")
            fetch_env_as_list!("ITEMS", as: :safe_module)

            import Enviable.Codex

            # Unsafe
            get_env("VAR") |> as_atom()
            fetch_env!("ITEMS") |> as_list(as: :module)

            # Safe
            get_env("VAR") |> as_safe_atom()
            fetch_env!("ITEMS") |> as_list(as: :safe_module)

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
    alias Enviable.Credo.Walker

    @unsafe_types [:atom, :module]

    @unsafe_functions %{
      Enviable => %{
        direct: [
          :get_env_as_atom,
          :fetch_env_as_atom,
          :fetch_env_as_atom!,
          :get_env_as_module,
          :fetch_env_as_module,
          :fetch_env_as_module!
        ],
        generic: [:get_env_as, :fetch_env_as, :fetch_env_as!],
        wrapper: [
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
      },
      Enviable.Codex => %{
        direct: [:as_atom, :as_module],
        generic: [:as],
        wrapper: [:as_base16, :as_base32, :as_base64, :as_url_base64, :as_hex32, :as_list]
      }
    }

    @doc false
    @impl Credo.Check
    def run(%SourceFile{} = source_file, params) do
      ctx = Context.build(source_file, params, __MODULE__)
      permit_with_allowed = Params.get(params, :permit_with_allowed, __MODULE__)

      result =
        Walker.calls(source_file, ctx, fn call, ctx ->
          check_call(ctx, call, permit_with_allowed)
        end)

      result.issues
    end

    defp check_call(ctx, %{module: module, fun: fun, args: args, meta: meta}, permit_with_allowed) do
      case get_forbidden_call(module, fun, args, permit_with_allowed) do
        {bad, suggestion, trigger} -> put_issue(ctx, issue_for(ctx, meta, bad, suggestion, trigger))
        nil -> ctx
      end
    end

    defp get_forbidden_call(module, fun, args, permit_with_allowed) do
      functions = Map.fetch!(@unsafe_functions, module)
      name = "#{inspect(module)}.#{fun}"

      cond do
        fun in functions.direct ->
          check_allowed_option(args, permit_with_allowed, name, "use :allowed option or #{safe_variant(fun)}", name)

        fun in functions.generic ->
          check_generic(args, permit_with_allowed, name)

        fun in functions.wrapper ->
          check_wrapper(args, permit_with_allowed, name)

        true ->
          nil
      end
    end

    defp safe_variant(fun), do: String.replace(to_string(fun), ~r/_(atom|module)/, "_safe_\\1")

    defp check_generic([_var, type | rest], permit_with_allowed, name) when type in @unsafe_types do
      check_allowed_option(
        rest,
        permit_with_allowed,
        "#{name}(..., :#{type})",
        "use :allowed option or :safe_#{type}",
        name
      )
    end

    defp check_generic([_var, {type_wrapper, type} | rest], permit_with_allowed, name) when type in @unsafe_types do
      check_allowed_option(
        rest,
        permit_with_allowed,
        "#{name}(..., {#{inspect(type_wrapper)}, :#{type}})",
        "use :allowed option or :safe_#{type}",
        name
      )
    end

    defp check_generic(_args, _permit_with_allowed, _name), do: nil

    # Encoded and list functions with as: :atom or as: :module
    defp check_wrapper(args, permit_with_allowed, name) do
      case option_value(args, :as) do
        {:ok, type} when type in @unsafe_types ->
          check_allowed_option(
            args,
            permit_with_allowed,
            "#{name}(..., as: :#{type})",
            "use :allowed option or as: :safe_#{type}",
            name
          )

        _ ->
          nil
      end
    end

    # Finds `key` in any literal keyword list argument. Arguments are ASTs, so lists may
    # contain anything (`[as]` is a list holding a variable AST).
    defp option_value(:capture, _key), do: :error

    defp option_value(args, key) do
      Enum.find_value(args, :error, fn
        opts when is_list(opts) ->
          Enum.find_value(opts, fn
            {^key, value} -> {:ok, value}
            _ -> nil
          end)

        _ ->
          nil
      end)
    end

    defp check_allowed_option(args, true = _permit_with_allowed, bad, suggestion, trigger) do
      case option_value(args, :allowed) do
        {:ok, _} -> nil
        :error -> {bad, suggestion, trigger}
      end
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
