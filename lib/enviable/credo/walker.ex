if Code.ensure_loaded?(Credo.Check) do
  # coveralls-ignore-next-line
  defmodule Enviable.Credo.Walker do
    @moduledoc false

    # Finds calls to Enviable and Enviable.Codex functions for the Enviable Credo checks.
    #
    # The walk follows lexical scope: `alias` and `import` apply to the following
    # expressions in the same block and anything nested in them, but not outside the
    # enclosing `defmodule`, function, or clause. Function heads are skipped, so
    # `def as_atom(value)` is not a call.
    #
    # Each call is passed to the visitor as a map:
    #
    # - `:module`: `Enviable` or `Enviable.Codex`
    # - `:fun`, `:arity`: the function called
    # - `:args`: the argument ASTs (a piped value is the first argument), or `:capture`
    #   for `&fun/arity`, where the arguments are unknown
    # - `:meta`: the call metadata
    #
    # A bare call or capture is reported only when the function is imported: `only:` and
    # `except:` are honoured, and the function must exist with that arity.

    @modules %{[:Enviable] => Enviable, [:Enviable, :Codex] => Enviable.Codex}

    @definitions [:def, :defp, :defmacro, :defmacrop]
    @skipped [:defguard, :defguardp, :defdelegate]

    @doc false
    def calls(source_file, acc, visitor) do
      {_scope, acc} = walk(Credo.SourceFile.ast(source_file), %{aliases: %{}, imports: %{}}, acc, visitor)
      acc
    end

    # Blocks pass scope from one expression to the next.
    defp walk({:__block__, _, exprs}, scope, acc, visitor) when is_list(exprs) do
      Enum.reduce(exprs, {scope, acc}, fn expr, {scope, acc} -> walk(expr, scope, acc, visitor) end)
    end

    defp walk({:alias, _, [target | opts]}, scope, acc, _visitor) do
      {track_alias(scope, target, opts), acc}
    end

    defp walk({:import, _, [{:__aliases__, _, segments} | opts]}, scope, acc, _visitor) do
      case module_for(scope, segments) do
        nil -> {scope, acc}
        module -> {put_in(scope, [:imports, module], import_filter(opts)), acc}
      end
    end

    defp walk({:defmodule, _, [_name, body]}, scope, acc, visitor) do
      {scope, walk_scoped(body, scope, acc, visitor)}
    end

    defp walk({definition, _, [_head | body]}, scope, acc, visitor) when definition in @definitions do
      {scope, walk_scoped(body, scope, acc, visitor)}
    end

    defp walk({skipped, _, args}, scope, acc, _visitor) when skipped in @skipped and is_list(args) do
      {scope, acc}
    end

    # Clause patterns and guards (`fn`, `case`, `with`, ...) are skipped; the body is a
    # new scope.
    defp walk({:->, _, [_patterns, body]}, scope, acc, visitor) do
      {scope, walk_scoped(body, scope, acc, visitor)}
    end

    # `lhs |> call(args)` is visited as `call(lhs, args)` so that argument positions match
    # direct calls.
    defp walk({:|>, _, [lhs, {callee, meta, args} = rhs]}, scope, acc, visitor) do
      {_, acc} = walk(lhs, scope, acc, visitor)

      if is_list(args) do
        acc = visit(callee, meta, [lhs | args], scope, acc, visitor)
        {scope, walk_all([callee | args], scope, acc, visitor)}
      else
        walk(rhs, scope, acc, visitor)
      end
    end

    defp walk({:&, _, [{:/, _, [callee, arity]}]}, scope, acc, visitor) when is_integer(arity) do
      {scope, visit_capture(callee, arity, scope, acc, visitor)}
    end

    defp walk({callee, meta, args}, scope, acc, visitor) when is_list(args) do
      acc = visit(callee, meta, args, scope, acc, visitor)
      {scope, walk_all([callee | args], scope, acc, visitor)}
    end

    defp walk({left, right}, scope, acc, visitor) do
      {scope, walk_all([left, right], scope, acc, visitor)}
    end

    defp walk(list, scope, acc, visitor) when is_list(list) do
      {scope, walk_all(list, scope, acc, visitor)}
    end

    defp walk(_ast, scope, acc, _visitor), do: {scope, acc}

    defp walk_scoped(ast, scope, acc, visitor) do
      {_scope, acc} = walk(ast, scope, acc, visitor)
      acc
    end

    defp walk_all(asts, scope, acc, visitor) do
      Enum.reduce(asts, acc, &walk_scoped(&1, scope, &2, visitor))
    end

    defp visit({:., _, [{:__aliases__, _, segments}, fun]}, meta, args, scope, acc, visitor) when is_atom(fun) do
      case module_for(scope, segments) do
        nil -> acc
        module -> report(module, fun, args, length(args), meta, acc, visitor)
      end
    end

    defp visit(fun, meta, args, scope, acc, visitor) when is_atom(fun) do
      case imported(scope, fun, length(args)) do
        nil -> acc
        module -> report(module, fun, args, length(args), meta, acc, visitor)
      end
    end

    defp visit(_callee, _meta, _args, _scope, acc, _visitor), do: acc

    # &Enviable.Codex.as_atom/1
    defp visit_capture({{:., _, [{:__aliases__, _, segments}, fun]}, meta, []}, arity, scope, acc, visitor)
         when is_atom(fun) do
      case module_for(scope, segments) do
        nil -> acc
        module -> report(module, fun, :capture, arity, meta, acc, visitor)
      end
    end

    # &as_atom/1
    defp visit_capture({fun, meta, context}, arity, scope, acc, visitor) when is_atom(fun) and is_atom(context) do
      case imported(scope, fun, arity) do
        nil -> acc
        module -> report(module, fun, :capture, arity, meta, acc, visitor)
      end
    end

    defp visit_capture(_callee, _arity, _scope, acc, _visitor), do: acc

    defp report(module, fun, args, arity, meta, acc, visitor) do
      if exported?(module, fun, arity) do
        visitor.(%{module: module, fun: fun, arity: arity, args: args, meta: meta}, acc)
      else
        acc
      end
    end

    defp exported?(module, fun, arity), do: Code.ensure_loaded?(module) and function_exported?(module, fun, arity)

    defp imported(scope, fun, arity) do
      Enum.find_value(scope.imports, fn {module, filter} ->
        if imports?(filter, fun, arity) and exported?(module, fun, arity), do: module
      end)
    end

    defp imports?(:all, _fun, _arity), do: true
    defp imports?(:none, _fun, _arity), do: false
    defp imports?({:only, funs}, fun, arity), do: {fun, arity} in funs
    defp imports?({:except, funs}, fun, arity), do: {fun, arity} not in funs

    # A later import of the same module replaces the earlier one. Options that are not
    # literals are treated as importing everything.
    defp import_filter([opts]) when is_list(opts) do
      cond do
        Keyword.has_key?(opts, :only) -> only_filter(Keyword.fetch!(opts, :only))
        Keyword.has_key?(opts, :except) -> except_filter(Keyword.fetch!(opts, :except))
        true -> :all
      end
    end

    defp import_filter(_opts), do: :all

    defp only_filter(:functions), do: :all
    defp only_filter(only) when only in [:macros, :sigils], do: :none

    defp only_filter(only) when is_list(only) do
      if function_list?(only), do: {:only, only}, else: :all
    end

    defp only_filter(_only), do: :all

    defp except_filter(except) when is_list(except) do
      if function_list?(except), do: {:except, except}, else: :all
    end

    defp except_filter(_except), do: :all

    defp function_list?(list), do: Enum.all?(list, &match?({fun, arity} when is_atom(fun) and is_integer(arity), &1))

    # Every alias is recorded so that `alias MyApp.Codex` shadows an earlier
    # `alias Enviable.Codex`. An alias that cannot be resolved (`alias __MODULE__.Codex`)
    # is recorded as `nil`.
    defp track_alias(scope, {:__aliases__, _, segments}, opts) do
      name =
        with [[_ | _] = alias_opts] <- opts,
             {:__aliases__, _, [name]} <- Keyword.get(alias_opts, :as) do
          name
        else
          _ -> List.last(segments)
        end

      put_alias(scope, name, resolve(scope, segments))
    end

    # alias Enviable.{Codex, Value}
    defp track_alias(scope, {{:., _, [{:__aliases__, _, base}, :{}]}, _, children}, _opts) do
      Enum.reduce(children, scope, fn
        {:__aliases__, _, segments}, scope -> put_alias(scope, List.last(segments), resolve(scope, base ++ segments))
        # coveralls-ignore-next-line - a multi-alias child is always an __aliases__ node
        _, scope -> scope
      end)
    end

    defp track_alias(scope, _target, _opts), do: scope

    defp put_alias(scope, name, path) when is_atom(name), do: put_in(scope, [:aliases, name], path)
    # coveralls-ignore-next-line - an alias name is always an atom segment
    defp put_alias(scope, _name, _path), do: scope

    defp module_for(scope, segments) do
      case resolve(scope, segments) do
        nil -> nil
        path -> Map.get(@modules, path)
      end
    end

    # `Elixir.Enviable.Codex` is never an alias.
    defp resolve(_scope, [Elixir | rest]) do
      if rest != [] and Enum.all?(rest, &is_atom/1), do: rest
    end

    defp resolve(scope, [head | rest] = segments) when is_atom(head) do
      if Enum.all?(rest, &is_atom/1) do
        case Map.fetch(scope.aliases, head) do
          {:ok, nil} -> nil
          {:ok, path} -> path ++ rest
          :error -> segments
        end
      end
    end

    defp resolve(_scope, _segments), do: nil
  end
end
