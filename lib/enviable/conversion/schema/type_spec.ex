defmodule Enviable.Conversion.Schema.TypeSpec do
  @moduledoc false

  # Builds quoted typespecs for the NimbleOptions types used by
  # Enviable.Conversion.Schema.
  #
  # NimbleOptions 1.1 renders `{:in, choices}` as `term()`, which loses the literal values
  # that make option typespecs useful (`:lower | :mixed | :upper`). Every schema entry
  # gets a `:type_spec` from here unless it provides its own.

  @spec quoted(term()) :: Macro.t()
  def quoted(:any), do: quote(do: term())
  def quoted(:atom), do: quote(do: atom())
  def quoted(:string), do: quote(do: String.t())
  def quoted(:boolean), do: quote(do: boolean())
  def quoted(:integer), do: quote(do: integer())
  def quoted(:non_neg_integer), do: quote(do: non_neg_integer())
  def quoted(:pos_integer), do: quote(do: pos_integer())
  def quoted(:float), do: quote(do: float())
  def quoted(nil), do: nil
  def quoted({:in, %Range{first: first, last: last, step: 1}}), do: quote(do: unquote(first)..unquote(last))
  def quoted({:in, values}) when is_list(values), do: union(values)

  def quoted({:or, types}) do
    types
    |> Enum.map(&quoted/1)
    |> union()
  end

  def quoted({:list, type}), do: [quoted(type)]
  def quoted({:map, key, value}), do: quote(do: %{optional(unquote(quoted(key))) => unquote(quoted(value))})
  def quoted({:fun, arity}), do: List.wrap({:->, [], [List.duplicate(quote(do: term()), arity), quote(do: term())]})
  def quoted({:tuple, types}), do: {:{}, [], Enum.map(types, &quoted/1)}
  def quoted({:struct, module}), do: quote(do: unquote(module).t())

  def quoted({:keyword_list, schema}) do
    schema
    |> Enum.map(fn {key, spec} -> {key, quoted(Keyword.fetch!(spec, :type))} end)
    |> union()
    |> List.wrap()
  end

  def quoted({:custom, _m, _f, _a}), do: quote(do: term())

  @doc "Joins quoted types (or literal values) into a quoted union, flattening nested unions."
  @spec union([Macro.t()]) :: Macro.t()
  def union(types) do
    types
    |> Enum.flat_map(&members/1)
    |> join()
  end

  defp members({:|, _, [left, right]}), do: members(left) ++ members(right)
  defp members(type), do: [type]

  defp join([one]), do: one
  defp join([first | rest]), do: {:|, [], [first, join(rest)]}
end
