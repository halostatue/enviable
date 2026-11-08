defmodule Enviable.Credo.WalkerTest do
  use Credo.Test.Case

  alias Enviable.Credo.UnsafeAtom
  alias Enviable.Credo.UnsafeEval

  defp issues(source, check) do
    source
    |> to_source_file()
    |> run_check(check)
  end

  describe "definitions" do
    test "function heads are not calls" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable.Codex

        def as_atom(value) when is_binary(value), do: value
        defp as_module(value), do: value
        def as_elixir(value), do: value
      end
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "function bodies are checked" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable.Codex

        def load(value), do: as_atom(value)
      end
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(1)
    end
  end

  describe "lexical scope" do
    test "an import does not leak into another module" do
      ~S'''
      defmodule A do
        import Enviable.Codex
      end

      defmodule B do
        def as_atom(value), do: value
        def load(value), do: as_atom(value)
      end
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "an alias does not leak into another module" do
      ~S'''
      defmodule A do
        alias Enviable.Codex
      end

      defmodule B do
        def load(value), do: Codex.as_atom(value)
      end
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "an alias does not leak out of a function" do
      ~S'''
      defmodule CredoSampleModule do
        def a do
          alias Enviable.Codex
          :ok
        end

        def b(value), do: Codex.as_atom(value)
      end
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "an import applies only after it appears" do
      ~S'''
      defmodule CredoSampleModule do
        def as_atom(value), do: value
        def a(value), do: as_atom(value)
      end

      import Enviable.Codex
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "file-level imports and aliases apply inside modules" do
      ~S'''
      import Enviable.Codex
      alias Enviable, as: E

      defmodule CredoSampleModule do
        def a(value), do: as_atom(value)
        def b, do: E.get_env_as_module("M")
      end
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(2)
    end
  end

  describe "import filters" do
    test "only: imports the listed arities" do
      ~S'''
      import Enviable.Codex, only: [as_atom: 1]

      as_atom(value)
      as_atom(value, :default)
      as_module(value)
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(1)
    end

    test "except: excludes the listed arities" do
      ~S'''
      import Enviable.Codex, except: [as_atom: 1]

      get_env("X") |> as_atom()
      as_module(value)
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(1)
    end

    test "only: :macros imports no functions" do
      ~S'''
      import Enviable.Codex, only: :macros

      as_atom(value)
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "a later import replaces the earlier one" do
      ~S'''
      import Enviable.Codex
      import Enviable.Codex, only: [get_env: 1]

      as_atom(value)
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end
  end

  describe "captures" do
    test "imported captures are reported" do
      ~S'''
      import Enviable.Codex

      Enum.map(values, &as_atom/1)
      get_env("X") |> then(&as_module/1)
      Enum.map(values, &as_elixir/1)
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(2)
    end

    test "remote captures are reported" do
      ~S'''
      Enum.map(values, &Enviable.Codex.as_atom/1)
      Enum.map(names, &Enviable.get_env_as_module/2)
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(2)
    end

    test "captures are not reported without an import or when filtered out" do
      ~S'''
      defmodule A do
        def as_atom(value), do: value
        def a(values), do: Enum.map(values, &as_atom/1)
      end

      defmodule B do
        import Enviable.Codex, except: [as_atom: 1]
        def b(values), do: Enum.map(values, &as_atom/1)
      end
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "captures of generic or wrapper conversions are not reported (type unknown)" do
      ~S'''
      Enum.map(values, &Enviable.Codex.as/3)
      Enum.map(values, &Enviable.Codex.as_list/2)
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "captures with arguments are checked as calls" do
      ~S'''
      import Enviable.Codex

      Enum.map(values, &as_atom(&1, allowed: [:a]))
      Enum.map(values, &as_atom(&1))
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(1)
    end

    test "UnsafeEval reports captures" do
      ~S'''
      import Enviable.Codex

      Enum.map(values, &as_elixir/1)
      Enum.map(values, &Enviable.Codex.as_erlang/1)
      Enum.map(values, &Enviable.get_env_as_elixir/1)
      '''
      |> issues(UnsafeEval)
      |> assert_issues(3)
    end
  end

  describe "non-keyword list arguments" do
    test "do not crash UnsafeAtom" do
      ~S'''
      Enviable.get_env_as_list("X", [as])
      Enviable.Codex.as_list(value, [as, 1])
      Enviable.get_env_as_atom("X", [allowed])
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(1)
    end

    test "do not crash UnsafeEval" do
      ~S'''
      Enviable.get_env_as_list("X", [as])
      Enviable.Codex.as_base64(value, [as, 1])
      '''
      |> issues(UnsafeEval)
      |> refute_issues()
    end
  end

  describe "Elixir. prefix" do
    test "is resolved for both modules" do
      ~S'''
      Elixir.Enviable.Codex.as_atom(value)
      Elixir.Enviable.get_env_as_atom("X")
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(2)
    end

    test "bypasses aliases" do
      ~S'''
      alias MyApp.Enviable
      alias MyApp.Codex

      Elixir.Enviable.Codex.as_atom(value)
      Enviable.Codex.as_atom(value)
      Codex.as_atom(value)
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(1)
    end

    test "works in alias and import" do
      ~S'''
      alias Elixir.Enviable.Codex
      import Elixir.Enviable

      Codex.as_erlang(value)
      get_env_as_elixir("X")
      '''
      |> issues(UnsafeEval)
      |> assert_issues(2)
    end
  end

  describe "ignored constructs (no crash, no false positive)" do
    test "imports, aliases, and defs of unrelated modules" do
      ~S'''
      defmodule CredoSampleModule do
        import MyApp.Helpers
        import MyApp.Codex, only: [as_atom: 1]
        alias MyApp.Thing

        defdelegate as_atom(value), to: Thing
        defguard is_thing(value) when is_integer(value)

        def run(value) do
          other = helper(value)
          Thing.as_atom(other)
        end
      end
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "anonymous function and case clause bodies are scoped and checked" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable.Codex

        def run(values) do
          Enum.map(values, fn value -> as_atom(value) end)

          case values do
            [head | _] -> as_module(head)
            [] -> :none
          end
        end
      end
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(2)
    end

    test "a bare alias inside a clause does not leak to a sibling clause" do
      ~S'''
      defmodule CredoSampleModule do
        def run(flag, value) do
          case flag do
            :a ->
              alias Enviable.Codex
              Codex.as_atom(value)

            :b ->
              Codex.as_atom(value)
          end
        end
      end
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(1)
    end

    test "piped calls without a parenthesised right side" do
      ~S'''
      defmodule CredoSampleModule do
        def run(value) do
          value |> String.trim() |> inspect
        end
      end
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "captures of unrelated functions and non-call captures" do
      ~S'''
      defmodule CredoSampleModule do
        def run(values) do
          Enum.map(values, &MyApp.Codex.as_atom/1)
          Enum.map(values, &String.trim/1)
          Enum.map(values, &(&1 + 1))
        end
      end
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "import option variants" do
      ~S'''
      defmodule A do
        import Enviable.Codex, only: :functions
        def run(value), do: as_atom(value)
      end

      defmodule B do
        import Enviable.Codex, only: :macros
        def run(value), do: as_atom(value)
      end

      defmodule C do
        import Enviable.Codex, only: :sigils
        def run(value), do: as_atom(value)
      end
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(1)
    end

    test "non-literal import filters import everything" do
      ~S'''
      defmodule CredoSampleModule do
        @funs [as_atom: 1]
        import Enviable.Codex, only: @funs
        def run(value), do: as_atom(value)
      end
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(1)
    end

    test "multi-alias with a non-alias child and an unresolved alias" do
      ~S'''
      defmodule CredoSampleModule do
        alias Enviable.{Codex, Value}
        alias __MODULE__.Inner

        def run(value) do
          Codex.as_atom(value)
          Inner.as_atom(value)
          Value.set?(value)
        end
      end
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(1)
    end

    test "alias of a bare __MODULE__ is ignored" do
      ~S'''
      defmodule CredoSampleModule do
        alias __MODULE__

        def run(value), do: CredoSampleModule.as_atom(value)
      end
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "import with trailing options but no only/except imports everything" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable.Codex, warn: false
        def run(value), do: as_atom(value)
      end
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(1)
    end

    test "except: with a non-list value imports everything" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable.Codex, except: :functions
        def run(value), do: as_atom(value)
      end
      '''
      |> issues(UnsafeAtom)
      |> assert_issues(1)
    end

    test "capture of a remote call on an atom module is ignored" do
      ~S'''
      defmodule CredoSampleModule do
        def run(values), do: Enum.map(values, &:erlang.abs/1)
      end
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "an imported name at an unexported arity is not reported" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable.Codex
        def run(value), do: as_atom(value, :one, :two, :three)
      end
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "a remote call at an unexported arity is not reported" do
      ~S'''
      defmodule CredoSampleModule do
        def run(value), do: Enviable.Codex.as_atom(value, :two, :three)
      end
      '''
      |> issues(UnsafeAtom)
      |> refute_issues()
    end

    test "UnsafeEval ignores captures of wrapper conversions (type unknown)" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable.Codex

        def run(values) do
          Enum.map(values, &as_base64/2)
          Enum.map(values, &Enviable.Codex.as_list/2)
          Enum.map(names, &Enviable.get_env_as_base64/2)
        end
      end
      '''
      |> issues(UnsafeEval)
      |> refute_issues()
    end
  end
end
