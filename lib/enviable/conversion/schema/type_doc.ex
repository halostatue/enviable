defmodule Enviable.Conversion.Schema.TypeDoc do
  # Describes the NimbleOptions types used by Enviable.Conversion.Schema, as Markdown (for
  # `:type_doc`) or plain text (for error messages).
  #
  # This is a separate module because Enviable.Conversion.Schema calls it while compiling.

  @moduledoc false

  @names %{
    atom: {"`t:atom/0`", "atom"},
    string: {"`t:String.t/0`", "string"},
    boolean: {"`t:boolean/0`", "boolean"},
    integer: {"`t:integer/0`", "integer"},
    non_neg_integer: {"`t:non_neg_integer/0`", "non-negative integer"},
    pos_integer: {"`t:pos_integer/0`", "positive integer"},
    float: {"`t:float/0`", "float"},
    nil: {"`nil`", "nil"}
  }

  @spec describe(term(), :markdown | :plain) :: String.t()
  def describe(:any, _format), do: "any term"

  def describe(type, format) when is_map_key(@names, type), do: pick(Map.fetch!(@names, type), format)

  def describe({:in, %Range{} = range}, format), do: "an integer in " <> code(inspect(range), format)

  def describe({:in, [value]}, format), do: code(inspect(value), format)

  def describe({:in, values}, format), do: "one of " <> Enum.map_join(values, ", ", &code(inspect(&1), format))

  def describe({:or, types}, format) do
    case Enum.map(types, &describe(&1, format)) do
      [one] -> one
      [one, two] -> one <> " or " <> two
      many -> Enum.join(Enum.drop(many, -1), ", ") <> ", or " <> List.last(many)
    end
  end

  def describe({:list, :any}, _format), do: "a list"
  def describe({:list, type}, format), do: "a list of " <> describe(type, format)
  def describe({:map, _key, _value}, _format), do: "a map"
  def describe({:fun, arity}, _format), do: "a function of arity #{arity}"

  def describe({:tuple, [:atom, :atom, {:list, :any}]}, format),
    do: "a " <> code("{module, function, args}", format) <> " tuple"

  def describe({:tuple, types}, format), do: "a tuple of " <> Enum.map_join(types, ", ", &describe(&1, format))

  def describe({:struct, module}, :markdown), do: "`t:#{inspect(module)}.t/0`"
  def describe({:struct, module}, :plain), do: inspect(module)

  def describe({:keyword_list, schema}, format),
    do: "a keyword list of " <> Enum.map_join(Keyword.keys(schema), ", ", &code(inspect(&1), format))

  def describe({:custom, _m, :__compiled_pattern__, []}, format),
    do: "a compiled pattern from " <> code(":binary.compile_pattern/1", format)

  def describe({:custom, _m, _f, _a}, _format), do: "a custom value"

  defp pick({markdown, _plain}, :markdown), do: markdown
  defp pick({_markdown, plain}, :plain), do: plain

  defp code(text, :markdown), do: "`#{text}`"
  defp code(text, :plain), do: text
end
