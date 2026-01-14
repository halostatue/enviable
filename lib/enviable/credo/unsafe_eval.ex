# credo:disable-for-this-file Credo.Check.Readability.ModuleDoc

if Code.ensure_loaded?(Credo.Check) do
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
            Enviable.get_env_as_list("ITEMS", as: :erlang)

        When using `import Enviable`, the check applies to bare function calls:

            import Enviable

            # Unsafe
            get_env_as_erlang("VAR")
            fetch_env_as_base64!("VAR", as: :elixir)

        Consider using safer alternatives. If code evaluation is necessary, ensure the
        environment variable source is completely trusted and controlled.
        """
      ]

    alias Credo.Check.Context
    alias Credo.SourceFile

    @doc false
    @impl Credo.Check
    def run(%SourceFile{} = source_file, params) do
      ctx = Context.build(source_file, params, __MODULE__)
      result = Credo.Code.prewalk(source_file, &walk/2, ctx)
      result.issues
    end

    defp walk({{:., _meta1, [{:__aliases__, _, [:Enviable]}, fun]}, meta, args} = ast, ctx) do
      case get_forbidden_call(fun, args) do
        {bad, trigger} ->
          {ast, put_issue(ctx, issue_for(ctx, meta, bad, trigger))}

        nil ->
          {ast, ctx}
      end
    end

    defp walk({fun, meta, args} = ast, %{module_contains_import: true} = ctx) when is_atom(fun) and is_list(args) do
      case get_forbidden_call(fun, args) do
        {bad, trigger} ->
          {ast, put_issue(ctx, issue_for(ctx, meta, bad, trigger))}

        nil ->
          {ast, ctx}
      end
    end

    defp walk({:import, _, [{:__aliases__, _, [:Enviable]}]} = ast, ctx) do
      {ast, Map.put(ctx, :module_contains_import, true)}
    end

    defp walk(ast, ctx) do
      {ast, ctx}
    end

    @unsafe_erlang [:get_env_as_erlang, :fetch_env_as_erlang, :fetch_env_as_erlang!]
    @unsafe_elixir [:get_env_as_elixir, :fetch_env_as_elixir, :fetch_env_as_elixir!]

    defp get_forbidden_call(fun, _args) when fun in @unsafe_erlang do
      {"Enviable.#{fun}", "Enviable.#{fun}"}
    end

    defp get_forbidden_call(fun, _args) when fun in @unsafe_elixir do
      {"Enviable.#{fun}", "Enviable.#{fun}"}
    end

    @unsafe_generic [:get_env_as, :fetch_env_as, :fetch_env_as!]

    defp get_forbidden_call(fun, [_var, type | _rest]) when fun in @unsafe_generic and type in [:erlang, :elixir] do
      {"Enviable.#{fun}(..., :#{type})", "Enviable.#{fun}"}
    end

    defp get_forbidden_call(fun, [_var, {_type_wrapper, type} | _rest])
         when fun in @unsafe_generic and type in [:erlang, :elixir] do
      {"Enviable.#{fun}(..., as: :#{type})", "Enviable.#{fun}"}
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

    defp get_forbidden_call(fun, args) when fun in @unsafe_encoded do
      case has_unsafe_as_option(args) do
        {:unsafe, type} ->
          {"Enviable.#{fun}(..., as: :#{type})", "Enviable.#{fun}"}

        nil ->
          nil
      end
    end

    defp get_forbidden_call(_fun, _args), do: nil

    defp has_unsafe_as_option(args) do
      Enum.find_value(args, fn
        opts when is_list(opts) ->
          case Keyword.get(opts, :as) do
            type when type in [:erlang, :elixir] -> {:unsafe, type}
            _ -> nil
          end

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
