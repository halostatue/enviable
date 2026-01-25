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
  end
end
