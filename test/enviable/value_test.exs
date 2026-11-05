defmodule Enviable.ValueTest do
  use ExUnit.Case

  alias Enviable.Value

  require Value

  defp plain(value \\ "secret"), do: %Value{name: "VAR", value: value}

  describe "secure/1" do
    test "wraps a set value in a closure" do
      secured = Value.secure(plain())

      assert Value.secure?(secured)
      assert is_function(secured.value, 0)
      assert secured.value.() == "secret"
    end

    test "is idempotent on an already-secure value" do
      secured = Value.secure(plain())

      assert Value.secure(secured) == secured
    end

    test "leaves an unset value unchanged" do
      unset = plain(nil)

      assert Value.secure(unset) == unset
      refute Value.secure?(unset)
    end

    test "the closure captures only the inner value, not the struct" do
      secured = Value.secure(plain())
      {:env, env} = :erlang.fun_info(secured.value, :env)

      refute Enum.any?(env, &match?(%Value{}, &1))
      assert env == ["secret"]
    end
  end

  describe "secure?/1" do
    test "true only when the inner value is a closure" do
      assert plain()
             |> Value.secure()
             |> Value.secure?()

      refute Value.secure?(plain())
      refute Value.secure?(plain(nil))
    end
  end

  describe "is_secure/1 guard" do
    test "matches a secured value" do
      assert matches_secure?(Value.secure(plain()))
      refute matches_secure?(plain())
    end
  end

  describe "set?/1 and unset?/1" do
    test "track the inner value, including when secured" do
      assert Value.set?(plain())
      refute Value.unset?(plain())

      refute Value.set?(plain(nil))
      assert Value.unset?(plain(nil))

      secured = Value.secure(plain())
      assert Value.set?(secured)
      refute Value.unset?(secured)
    end
  end

  describe "__unwrap__/1" do
    test "returns the inner value for plain, secure, and unset values" do
      assert Value.__unwrap__(plain()) == "secret"

      assert plain()
             |> Value.secure()
             |> Value.__unwrap__() == "secret"

      assert Value.__unwrap__(plain(nil)) == nil
    end
  end

  describe "String.Chars" do
    test "unwraps a secure value" do
      assert to_string(Value.secure(plain())) == "secret"
      assert "env.#{Value.secure(plain())}" == "env.secret"
    end

    test "renders plain and unset values" do
      assert to_string(plain()) == "secret"
      assert to_string(plain(nil)) == ""
    end
  end

  defp matches_secure?(value) when Value.is_secure(value), do: true
  defp matches_secure?(_value), do: false
end
