# credo:disable-for-this-file Credo.Check.Readability.ModuleDoc

if Code.ensure_loaded?(Credo.Check) do
  # coveralls-ignore-next-line
  defmodule Enviable.Credo.UnsafeEval do
    use Credo.Check,
      id: "ENV002",
      base_priority: :high,
      category: :warning,
      explanations: [
        check: """
        Evaluating Erlang or Elixir code from environment variables is unsafe as it
        executes arbitrary code in the context of your application.

        Enviable functions that evaluate code should not be used with untrusted input:

            # Unsafe - evaluates arbitrary Erlang code
            Enviable.get_env_as_erlang("VAR")
            Enviable.fetch_env_as_erlang!("VAR")

            # Unsafe - evaluates arbitrary Elixir code
            Enviable.get_env_as_elixir("VAR")
            Enviable.fetch_env_as_elixir!("VAR")

        This also applies to generic conversion functions and encoded types:

            # Unsafe
            Enviable.get_env_as("VAR", :erlang)
            Enviable.get_env_as("VAR", {:base64, :elixir})
            Enviable.get_env_as_base64("VAR", as: :erlang)

        The same conversions in `Enviable.Codex` are checked, including piped calls:

            # Unsafe
            Enviable.Codex.get_env("VAR") |> Enviable.Codex.as_erlang()
            Enviable.Codex.as(value, {:base64, :elixir})

        When using `import Enviable` or `import Enviable.Codex`, the check applies to
        bare function calls:

            import Enviable

            # Unsafe
            get_env_as_erlang("VAR")
            fetch_env_as_base64!("VAR", as: :elixir)

            import Enviable.Codex

            # Unsafe
            get_env("VAR") |> as_elixir()
            fetch_env!("VAR") |> as_base64(as: :erlang)

        Consider using safer alternatives. If code evaluation is necessary, ensure the
        environment variable source is completely trusted and controlled.
        """
      ]

    alias Credo.Check.Context
    alias Credo.SourceFile
    alias Enviable.Credo.Walker

    @unsafe_types [:erlang, :elixir]

    @unsafe_functions %{
      Enviable => %{
        direct: [
          :get_env_as_erlang,
          :fetch_env_as_erlang,
          :fetch_env_as_erlang!,
          :get_env_as_elixir,
          :fetch_env_as_elixir,
          :fetch_env_as_elixir!
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
        direct: [:as_erlang, :as_elixir],
        generic: [:as],
        wrapper: [:as_base16, :as_base32, :as_base64, :as_url_base64, :as_hex32, :as_list]
      }
    }

    @doc false
    @impl Credo.Check
    def run(%SourceFile{} = source_file, params) do
      ctx = Context.build(source_file, params, __MODULE__)
      result = Walker.calls(source_file, ctx, &check_call(&2, &1))
      result.issues
    end

    defp check_call(ctx, %{module: module, fun: fun, args: args, meta: meta}) do
      case get_forbidden_call(module, fun, args) do
        {bad, trigger} -> put_issue(ctx, issue_for(ctx, meta, bad, trigger))
        nil -> ctx
      end
    end

    defp get_forbidden_call(module, fun, args) do
      functions = Map.fetch!(@unsafe_functions, module)
      name = "#{inspect(module)}.#{fun}"

      cond do
        fun in functions.direct -> {name, name}
        fun in functions.generic -> check_generic(args, name)
        fun in functions.wrapper -> check_wrapper(args, name)
        true -> nil
      end
    end

    defp check_generic([_var, type | _rest], name) when type in @unsafe_types do
      {"#{name}(..., :#{type})", name}
    end

    defp check_generic([_var, {type_wrapper, type} | _rest], name) when type in @unsafe_types do
      {"#{name}(..., {#{inspect(type_wrapper)}, :#{type}})", name}
    end

    defp check_generic(_args, _name), do: nil

    # Encoded and list functions with as: :erlang or as: :elixir
    defp check_wrapper(:capture, _name), do: nil

    defp check_wrapper(args, name) do
      Enum.find_value(args, fn
        opts when is_list(opts) ->
          # Arguments are ASTs, so lists may contain anything (`[as]` holds a variable).
          Enum.find_value(opts, fn
            {:as, type} when type in @unsafe_types -> {"#{name}(..., as: :#{type})", name}
            _ -> nil
          end)

        _ ->
          nil
      end)
    end

    defp issue_for(ctx, meta, call, trigger) do
      format_issue(ctx,
        message: "#{call} evaluates arbitrary code from environment variables.",
        trigger: trigger,
        line_no: meta[:line]
      )
    end
  end
end
