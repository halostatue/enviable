defmodule Enviable.Conversion.TimeoutParser do
  @moduledoc false

  import NimbleParsec

  # Parse integers with optional underscored in them.
  integer_with_underscores =
    [?0..?9]
    |> ascii_char()
    |> repeat(choice([ascii_char([?0..?9]), ignore(ascii_char([?_]))]))
    |> reduce({:parse_integer, []})

  # Parse suffix variations
  day_suffix = choice([string("days"), string("day"), string("d")])
  hour_suffix = choice([string("hours"), string("hour"), string("h")])
  millisecond_suffix = choice([string("milliseconds"), string("millisecond"), string("ms")])
  minute_suffix = choice([string("minutes"), string("minute"), string("m")])
  second_suffix = choice([string("seconds"), string("second"), string("s")])
  week_suffix = choice([string("weeks"), string("week"), string("w")])

  # Parse a timeout component with suffix. In `concat(choice(…))`, the order matters to
  # ensure that `ms` is not parsed as `minute`.
  #
  # The suffix is considered optional, but the `reduce` step ensures that this only
  # applies for `millisecond` suffixes and that a bare value may only be at the end.
  timeout_component =
    integer_with_underscores
    |> optional(
      [?\s]
      |> ascii_char()
      |> repeat()
      |> ignore()
      |> concat(
        choice([
          replace(millisecond_suffix, :millisecond),
          replace(minute_suffix, :minute),
          replace(second_suffix, :second),
          replace(week_suffix, :week),
          replace(day_suffix, :day),
          replace(hour_suffix, :hour)
        ])
      )
    )
    |> reduce({:build_timeout_component, []})

  # Parse multiple timeout components separated by spaces

  timeout_components =
    repeat(
      timeout_component,
      [?\s]
      |> ascii_char()
      |> times(min: 0)
      |> ignore()
      |> concat(timeout_component)
    )

  # Parse a timeout string with possible trailing whitespace
  timeout_string =
    timeout_components
    |> optional(ignore(repeat(ascii_char([?\s]))))
    |> eos()

  def parse("infinity"), do: {:ok, :infinity}

  def parse(input) when is_binary(input) do
    case parse_timeout(input) do
      {:ok, result, "", _, _, _} -> validate_timeout_list(result)
      {:error, reason, _, _, _, _} -> {:error, reason}
    end
  end

  defparsecp :parse_timeout, timeout_string

  defp parse_integer(chars) do
    chars
    |> Enum.reject(&(&1 == ?_))
    |> List.to_string()
    |> String.to_integer()
  end

  defp build_timeout_component([value]), do: {value, :millisecond, :implicit}
  defp build_timeout_component([value, suffix]), do: {value, suffix, :explicit}

  defp validate_timeout_list(components) do
    with :ok <- check_implicit_ms(components),
         :ok <- check_for_duplicates(components) do
      {:ok, Enum.map(components, fn {value, suffix, _} -> {suffix, value} end)}
    end
  end

  defp check_for_duplicates(components) do
    suffixes = Enum.map(components, fn {_, suffix, _} -> suffix end)
    unique_suffixes = Enum.uniq(suffixes)

    if length(suffixes) == length(unique_suffixes) do
      :ok
    else
      duplicate = List.first(suffixes -- unique_suffixes)
      {:error, "duplicate suffix: #{duplicate}"}
    end
  end

  defp check_implicit_ms(components) do
    implicit_positions =
      components
      |> Enum.with_index()
      |> Enum.filter(&match?({{_, :millisecond, :implicit}, _}, &1))
      |> Enum.map(fn {_, index} -> index end)

    case implicit_positions do
      [] ->
        # No implicit milliseconds
        :ok

      [pos] ->
        # Single implicit millisecond must be at the end
        if pos == length(components) - 1 do
          :ok
        else
          {:error, "unsuffixed number must be at the end"}
        end

      _ ->
        # Multiple implicit milliseconds not allowed
        {:error, "unsuffixed number must be at the end"}
    end
  end
end
