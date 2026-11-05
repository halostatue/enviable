defmodule Enviable.CodexTest do
  use ExUnit.Case

  alias Enviable.Codex
  alias Enviable.Value

  doctest Enviable.Codex, import: true

  @test_var "ENVIABLE_TEST_VAR"

  setup do
    System.delete_env(@test_var)

    for v <- ~w[DECIMAL DURATION FLAG FLOAT JSON LIST LOG_LEVEL NAME PEM PORT TERM TIMEOUT UNSET],
        do: System.delete_env(v)

    :ok
  end

  describe "env maps holding a Value" do
    test "fetch_env_map/2 preserves a stored Value, keeping it secure" do
      secured = Value.secure(%Value{name: "ORIG", value: "s3cr3t", source: :map})

      {:ok, value} = Codex.fetch_env_map(%{"PORT" => secured}, "PORT")

      assert Value.secure?(value)
      assert value.name == "PORT"
      assert value.source == :map
      assert to_string(value) == "s3cr3t"
    end

    test "fetch_env_map!/2 preserves a stored Value" do
      stored = %Value{name: "ORIG", value: "4000", source: :map}

      value = Codex.fetch_env_map!(%{"PORT" => stored}, "PORT")

      assert value.name == "PORT"
      assert to_string(value) == "4000"
    end
  end

  describe "put_env/1 list variant" do
    test "sets each Value in the list" do
      :ok =
        Codex.put_env([
          %Value{name: "PORT", value: "4000"},
          %Value{name: "NAME", value: "app"}
        ])

      assert "PORT"
             |> Codex.get_env()
             |> to_string() == "4000"

      assert "NAME"
             |> Codex.get_env()
             |> to_string() == "app"
    end

    test "a nil-valued Value in the list erases its name" do
      System.put_env("PORT", "4000")

      :ok =
        Codex.put_env([
          %Value{name: "PORT", value: nil},
          %Value{name: "NAME", value: "app"}
        ])

      assert "PORT"
             |> Codex.get_env()
             |> Codex.unset?()

      assert "NAME"
             |> Codex.get_env()
             |> to_string() == "app"
    end

    test "an empty list is a no-op" do
      assert Codex.put_env([]) == :ok
    end

    test "accepts {key, value} pairs and mixes them with Values" do
      :ok =
        Codex.put_env([
          {"PORT", "4000"},
          %Value{name: "NAME", value: "app"}
        ])

      assert "PORT"
             |> Codex.get_env()
             |> to_string() == "4000"

      assert "NAME"
             |> Codex.get_env()
             |> to_string() == "app"
    end

    test "a {key, nil} pair erases the key" do
      System.put_env("PORT", "4000")

      :ok = Codex.put_env([{"PORT", nil}])

      assert "PORT"
             |> Codex.get_env()
             |> Codex.unset?()
    end

    test "a key containing \"=\" raises" do
      assert_raise ArgumentError, ~r/cannot execute put_env\/1 for key with/, fn ->
        Codex.put_env([{"FOO=BAR", "BAZ"}])
      end
    end
  end

  describe "put_env/1 map variant" do
    test "sets each name-value pair" do
      :ok = Codex.put_env(%{"PORT" => "4000", "NAME" => "app"})

      assert "PORT"
             |> Codex.get_env()
             |> to_string() == "4000"

      assert "NAME"
             |> Codex.get_env()
             |> to_string() == "app"
    end

    test "a nil map value erases the key (System.put_env/1 semantics)" do
      System.put_env("PORT", "4000")

      :ok = Codex.put_env(%{"PORT" => nil, "NAME" => "app"})

      assert "PORT"
             |> Codex.get_env()
             |> Codex.unset?()

      assert "NAME"
             |> Codex.get_env()
             |> to_string() == "app"
    end

    test "an empty map is a no-op" do
      assert Codex.put_env(%{}) == :ok
    end
  end
end
