defmodule Enviable.Credo.UnsafeAtomTest do
  use Credo.Test.Case

  alias Enviable.Credo.UnsafeAtom

  describe "no issues reported" do
    test "_as_safe_{atom,module}" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_safe_atom("VAR")
          Enviable.fetch_env_as_safe_atom("VAR")
          Enviable.fetch_env_as_safe_atom!("VAR")
          Enviable.get_env_as_safe_module("MODULE")
          Enviable.fetch_env_as_safe_module("MODULE")
          Enviable.fetch_env_as_safe_module!("MODULE")
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> refute_issues()
    end

    test "_as_{atom,module} with :allowed option (permit_with_allowed: true)" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_atom("VAR", allowed: [:foo, :bar])
          Enviable.fetch_env_as_module!("MODULE", allowed: [Foo, Bar])
          Enviable.get_env_as("VAR", :atom, allowed: [:foo])
          Enviable.get_env_as_base64("VAR", as: :module, allowed: [Foo])
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom, permit_with_allowed: true)
      |> refute_issues()
    end

    test "only reports on Enviable functions" do
      ~S'''
      defmodule CredoSampleModule do
        def get_env_as_atom(var) do
          var
          |> System.get_env()
          |> String.to_atom()
        end

        def fetch_env_as_module!(var) do
          var
          |> System.fetch_env!()
          |> Module.concat()
        end
      end

      CredoSampleModule.get_env_as_atom("VAR")
      CredoSampleModule.fetch_env_as_module!("VAR")
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> refute_issues()
    end

    test "_as_safe_{atom,module} when imported " do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable

        def some_function do
          get_env_as_safe_atom("VAR")
          fetch_env_as_safe_module!("MODULE")
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> refute_issues()
    end

    test "ignores non-atom / module conversions" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_base64("VAR", as: :integer)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> refute_issues()
    end
  end

  describe "issues reported" do
    test "_as_atom" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_atom("VAR")
          Enviable.fetch_env_as_atom("VAR")
          Enviable.fetch_env_as_atom!("VAR")
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues()
    end

    test "_as_module" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_module("MODULE")
          Enviable.fetch_env_as_module("MODULE")
          Enviable.fetch_env_as_module!("MODULE")
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues()
    end

    test "_as(var, :atom)" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as("VAR", :atom)
          Enviable.fetch_env_as("VAR", :atom)
          Enviable.fetch_env_as!("VAR", :atom)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues()
    end

    test "_as(var, :module)" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as("VAR", :module)
          Enviable.fetch_env_as("VAR", :module)
          Enviable.fetch_env_as!("VAR", :module)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues()
    end

    test "_as(var, {encoded, :atom})" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as("VAR", {:base64, :atom})
          Enviable.fetch_env_as("VAR", {:list, :atom})
          Enviable.fetch_env_as!("VAR", {:base16, :atom})
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues()
    end

    test "_as(var, {encoded, :module})" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as("VAR", {:base64, :module})
          Enviable.fetch_env_as("VAR", {:list, :module})
          Enviable.fetch_env_as!("VAR", {:base32, :module})
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues()
    end

    test "as_{encoded}(var, as: :atom)" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_base64("VAR", as: :atom)
          Enviable.fetch_env_as_list("VAR", as: :atom)
          Enviable.fetch_env_as_base16!("VAR", as: :atom)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues()
    end

    test "as_{encoded}(var, as: :module)" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_base32("VAR", as: :module)
          Enviable.fetch_env_as_hex32("VAR", as: :module)
          Enviable.fetch_env_as_url_base64!("VAR", as: :module)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues()
    end

    test "always reports with permit_with_allowed: false" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_atom("VAR", allowed: [:foo, :bar])
          Enviable.get_env_as_module("VAR", allowed: [Foo, Bar])
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom, permit_with_allowed: false)
      |> assert_issues()
    end

    test "reports when :allowed is missing and permit_with_allowed: true" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_atom("VAR")
          Enviable.get_env_as_module("VAR")
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom, permit_with_allowed: true)
      |> assert_issues()
    end

    test "reports when imported" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable

        def some_function do
          get_env_as_atom("VAR")
          fetch_env_as_module!("MODULE")
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues()
    end

    test "reports imported generic with :atom or :module type" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable

        def some_function do
          get_env_as("VAR", :atom)
          fetch_env_as!("VAR", :module)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues()
    end

    test "reports piped Enviable calls" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable

        def some_function do
          "VAR" |> Enviable.get_env_as(:atom)
          "VAR" |> get_env_as_atom()
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues(2)
    end

    test "reports import Enviable with options" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable, only: [get_env_as_atom: 1]

        def some_function do
          get_env_as_atom("VAR")
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues(1)
    end
  end

  describe "Enviable.Codex: no issues reported" do
    test "safe and :allowed conversions" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable.Codex

        def some_function do
          get_env("VAR") |> as_safe_atom()
          get_env("VAR") |> as(:safe_module)
          get_env("VAR") |> as_list(as: :safe_atom)
          get_env("VAR") |> as_atom(allowed: [:foo])
          get_env("VAR") |> as_module(allowed: [Foo])
          get_env("VAR") |> as({:list, :atom}, allowed: [:foo])
          Enviable.Codex.as_safe_module(get_env("VAR"))
          Enviable.Codex.as_base64(get_env("VAR"), as: :integer)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> refute_issues()
    end

    test "bare as_* calls without import Enviable.Codex" do
      ~S'''
      defmodule CredoSampleModule do
        def as_atom(value), do: String.to_atom(value)

        def some_function do
          as_atom("VAR")
          "VAR" |> as_atom()
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> refute_issues()
    end
  end

  describe "Enviable.Codex: issues reported" do
    test "remote calls" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function(value) do
          Enviable.Codex.as_atom(value)
          Enviable.Codex.as_module(value)
          Enviable.Codex.as(value, :atom)
          Enviable.Codex.as(value, {:list, :module})
          Enviable.Codex.as_base64(value, as: :atom)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues(5)
    end

    test "piped remote calls" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.Codex.get_env("VAR") |> Enviable.Codex.as_atom()
          "VAR" |> Enviable.Codex.get_env() |> Enviable.Codex.as(:module)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues(2)
    end

    test "imported calls" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable.Codex

        def some_function do
          get_env("VAR") |> as_atom()
          fetch_env!("VAR") |> as({:base64, :module})
          fetch_env!("VAR") |> as_list(as: :atom)
          as_module(get_env("VAR"))
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues(4)
    end

    test "both modules imported" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable
        import Enviable.Codex
        import Enviable

        def some_function do
          get_env_as_atom("VAR")
          get_env("VAR") |> as_atom()
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues(2)
    end

    test "always reports with permit_with_allowed: false" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable.Codex

        def some_function do
          get_env("VAR") |> as_atom(allowed: [:foo])
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom, permit_with_allowed: false)
      |> assert_issues(1)
    end

    test "messages name Enviable.Codex and the safe variant" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable.Codex

        def some_function do
          get_env("VAR") |> as_module()
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issue(fn issue ->
        assert issue.message ==
                 "Enviable.Codex.as_module can cause atom exhaustion. " <>
                   "Prefer to use :allowed option or as_safe_module."
      end)
    end
  end
end

defmodule Enviable.Credo.UnsafeAtomAliasTest do
  use Credo.Test.Case

  alias Enviable.Credo.UnsafeAtom

  describe "aliases: issues reported" do
    test "alias Enviable.Codex" do
      ~S'''
      defmodule CredoSampleModule do
        alias Enviable.Codex

        def some_function(value) do
          Codex.as_atom(value)
          value |> Codex.as(:module)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues(2)
    end

    test "alias with :as" do
      ~S'''
      defmodule CredoSampleModule do
        alias Enviable, as: E
        alias Enviable.Codex, as: C

        def some_function(value) do
          C.as_atom(value)
          E.get_env_as_atom("VAR")
          E.Codex.as_module(value)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues(3)
    end

    test "multi-alias" do
      ~S'''
      defmodule CredoSampleModule do
        alias Enviable.{Codex, Value}

        def some_function(value) do
          Codex.as_list(value, as: :atom)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues(1)
    end

    test "import of an aliased module" do
      ~S'''
      defmodule CredoSampleModule do
        alias Enviable.Codex
        import Codex

        def some_function do
          get_env("VAR") |> as_atom()
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> assert_issues(1)
    end
  end

  describe "aliases: no issues reported" do
    test "aliases to other modules" do
      ~S'''
      defmodule CredoSampleModule do
        alias MyApp.Codex
        alias MyApp.Enviable

        def some_function(value) do
          Codex.as_atom(value)
          Enviable.get_env_as_atom("VAR")
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> refute_issues()
    end

    test "a later alias shadows Enviable.Codex" do
      ~S'''
      defmodule CredoSampleModule do
        alias Enviable.Codex
        alias MyApp.Codex

        def some_function(value) do
          Codex.as_atom(value)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> refute_issues()
    end

    test "unresolvable aliases" do
      ~S'''
      defmodule CredoSampleModule do
        alias __MODULE__.Codex

        def some_function(value) do
          Codex.as_atom(value)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeAtom)
      |> refute_issues()
    end
  end
end
