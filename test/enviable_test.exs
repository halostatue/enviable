defmodule EnviableTest do
  use ExUnit.Case

  doctest Enviable

  @test_var "ENVIABLE_TEST_VAR"

  setup do
    System.delete_env(@test_var)
    for v <- ~w[FLAG FLOAT JSON LIST LOG_LEVEL NAME PEM PORT TERM UNSET], do: System.delete_env(v)
    :ok
  end

  describe "Enviable wraps System env functions" do
    test "get_env/put_env/delete_env" do
      assert Enviable.get_env(@test_var) == nil
      assert Enviable.get_env(@test_var, "SAMPLE") == "SAMPLE"

      assert Enviable.fetch_env(@test_var) == :error

      message = "could not fetch environment variable #{inspect(@test_var)} because it is not set"
      assert_raise System.EnvError, message, fn -> Enviable.fetch_env!(@test_var) end

      Enviable.put_env(@test_var, "SAMPLE")

      assert Enviable.get_env(@test_var) == "SAMPLE"
      assert Enviable.get_env()[@test_var] == "SAMPLE"
      assert Enviable.fetch_env(@test_var) == {:ok, "SAMPLE"}
      assert Enviable.fetch_env!(@test_var) == "SAMPLE"

      Enviable.delete_env(@test_var)
      assert Enviable.get_env(@test_var) == nil

      assert_raise ArgumentError, ~r[cannot execute System.put_env/2 for key with \"=\"], fn ->
        Enviable.put_env("FOO=BAR", "BAZ")
      end
    end

    test "put_env/2" do
      Enviable.put_env(%{@test_var => "MAP_STRING"})
      assert Enviable.get_env(@test_var) == "MAP_STRING"

      Enviable.put_env([{String.to_atom(@test_var), "KW_ATOM"}])
      assert Enviable.get_env(@test_var) == "KW_ATOM"

      Enviable.put_env([{String.to_atom(@test_var), nil}])
      assert Enviable.get_env(@test_var) == nil
    end
  end

  describe "test cases from discovered bugs" do
    test "get_env_as_boolean works with UNSET and downcase" do
      assert false == Enviable.get_env_as_boolean("UNSET", downcase: true)
    end

    test "get_env_as_list works with UNSET and default" do
      assert [] == Enviable.get_env_as_list("UNSET", default: [])
    end
  end
end
