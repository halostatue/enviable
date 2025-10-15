defmodule Enviable.Conversion.TimeoutParserTest do
  use ExUnit.Case, async: true

  alias Enviable.Conversion.TimeoutParser

  describe "parse/1" do
    test "handles infinity" do
      assert {:ok, :infinity} == TimeoutParser.parse("infinity")
    end

    @units [second: "s", minute: "m", hour: "h", day: "d", week: "w", millisecond: "ms"]

    test "parses abbreviated suffixed values" do
      for {name, suffix} <- @units do
        assert {:ok, [{^name, 30}]} = TimeoutParser.parse("30#{suffix}")
        assert {:ok, [{^name, 30}]} = TimeoutParser.parse("30 #{suffix}")
        assert {:ok, [{^name, 30}]} = TimeoutParser.parse("30  #{suffix}")
        assert {:ok, [{^name, 30}]} = TimeoutParser.parse("30 #{suffix} ")
      end
    end

    test "parses singular suffix variations" do
      for {name, _} <- @units do
        assert {:ok, [{^name, 30}]} = TimeoutParser.parse("30#{name}")
        assert {:ok, [{^name, 30}]} = TimeoutParser.parse("30  #{name}")
        assert {:ok, [{^name, 30}]} = TimeoutParser.parse("30 #{name} ")
      end
    end

    test "parses plural suffix variations" do
      for {name, _} <- @units do
        assert {:ok, [{^name, 30}]} = TimeoutParser.parse("30#{name}s")
        assert {:ok, [{^name, 30}]} = TimeoutParser.parse("30  #{name}s")
        assert {:ok, [{^name, 30}]} = TimeoutParser.parse("30 #{name}s ")
      end
    end

    test "parses integers with underscores" do
      for {name, _} <- @units do
        assert {:ok, [{^name, 3000}]} = TimeoutParser.parse("3_0_0_0#{name}s")
      end
    end

    test "parses unsuffixed values as milliseconds" do
      assert {:ok, [millisecond: 100]} = TimeoutParser.parse("100")
      assert {:ok, [millisecond: 1000]} = TimeoutParser.parse("1_000")
    end

    test "parses multiple timeout components" do
      assert {:ok, [day: 3, hour: 2, minute: 5, second: 2, millisecond: 100]} =
               TimeoutParser.parse("3d 2h 5m 2s 100")

      assert {:ok, [hour: 1, minute: 30]} = TimeoutParser.parse("1h 30m")
      assert {:ok, [week: 2, day: 3]} = TimeoutParser.parse("2w 3d")
    end

    test "handles mixed spacing in multiple components" do
      assert {:ok, [day: 1, hour: 2]} = TimeoutParser.parse("1d  2h")
      assert {:ok, [hour: 1, minute: 30]} = TimeoutParser.parse("1 h 30 m")
      assert {:ok, [hour: 1, minute: 30]} = TimeoutParser.parse("1 h 30 m ")
    end

    test "rejects duplicate suffixes" do
      assert {:error, "duplicate suffix: day"} = TimeoutParser.parse("2d 3d")
      assert {:error, "duplicate suffix: second"} = TimeoutParser.parse("30s 45s")
      assert {:error, "duplicate suffix: millisecond"} = TimeoutParser.parse("100ms 200ms")
    end

    test "rejects unsuffixed numbers not at the end" do
      assert {:error, "unsuffixed number must be at the end"} = TimeoutParser.parse("100 100s")
      assert {:error, "unsuffixed number must be at the end"} = TimeoutParser.parse("50 2h 30m")
      assert {:error, "unsuffixed number must be at the end"} = TimeoutParser.parse("100 100")
    end

    test "allows unsuffixed number at the end" do
      assert {:ok, [day: 3, hour: 2, minute: 5, second: 2, millisecond: 100]} =
               TimeoutParser.parse("3d 2h 5m 2s 100")

      assert {:ok, [hour: 1, millisecond: 500]} = TimeoutParser.parse("1h 500")
    end

    test "rejects invalid input" do
      assert {:error, _} = TimeoutParser.parse("")
      assert {:error, _} = TimeoutParser.parse("abc")
      assert {:error, _} = TimeoutParser.parse("30x")
      assert {:error, _} = TimeoutParser.parse("30 x")
    end

    test "rejects uppercase suffixes" do
      for {name, _} <- @units do
        name = to_string(name)
        assert {:error, _} = TimeoutParser.parse("30#{String.upcase(name)}")
        assert {:error, _} = TimeoutParser.parse("30 #{String.upcase(name)}")
        assert {:error, _} = TimeoutParser.parse("30#{String.upcase(name)}S")
        assert {:error, _} = TimeoutParser.parse("30 #{String.upcase(name)}S")
      end

      for {_, suffix} <- @units do
        assert {:error, _} = TimeoutParser.parse("30#{String.upcase(suffix)}")
        assert {:error, _} = TimeoutParser.parse("30 #{String.upcase(suffix)}")
      end
    end

    test "handles edge cases" do
      assert {:ok, [millisecond: 0]} = TimeoutParser.parse("0")
      assert {:ok, [second: 0]} = TimeoutParser.parse("0s")
      assert {:ok, [week: 999]} = TimeoutParser.parse("999w")
    end

    test "complex valid examples" do
      assert {:ok, [week: 1, day: 2, hour: 3, minute: 4, second: 5, millisecond: 600]} =
               TimeoutParser.parse("1w 2d 3h 4m 5s 600")

      assert {:ok, [week: 1, day: 2, hour: 3, minute: 4, second: 5, millisecond: 600]} =
               TimeoutParser.parse("1w2d3h4m5s600")

      assert {:ok, [week: 1, day: 2, hour: 3, minute: 4, second: 5, millisecond: 600]} =
               TimeoutParser.parse("1w2d3h4m5s600ms")

      assert {:ok, [day: 7, millisecond: 500]} = TimeoutParser.parse("7d 500")
      assert {:ok, [hour: 24]} = TimeoutParser.parse("24 hours")
    end
  end
end
