defmodule Enviable.Credo.UnsafeEvalTest do
  use Credo.Test.Case

  alias Enviable.Credo.UnsafeEval

  describe "no issues reported" do
    test "ignores other functions" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_atom("VAR")
          Enviable.get_env_as_integer("PORT")
          Enviable.get_env_as_json("JSON")
          Enviable.fetch_env_as_boolean("FLAG")
          Enviable.fetch_env_as_float!("FLOAT")
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> refute_issues()
    end

    test "only reports on Enviable functions" do
      ~S'''
      defmodule CredoSampleModule do
        def get_env_as_erlang(var) do
          {:ok, term, _} =
            var
            |> System.get_env()
            |> String.to_charlist()
            |> :erl_scan.string()

          {:ok, result} = :erl_parse.parse_term(term)
        end

        def fetch_env_as_elixir!(var) do
          {term, _} =
            var
            |> System.fetch_env!()
            |> Code.string_to_quoted!()
            |> Code.eval_quoted!()

          term
        end
      end

      CredoSampleModule.get_env_as_erlang("VAR")
      CredoSampleModule.fetch_env_as_elixir!("VAR")
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> refute_issues()
    end

    test "ignores other functions when imported" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable

        def some_function do
          get_env_as_integer("PORT")
          fetch_env_as_json!("JSON")
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> refute_issues()
    end
  end

  describe "issues reported" do
    test "_as_erlang" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_erlang("VAR")
          Enviable.fetch_env_as_erlang("VAR")
          Enviable.fetch_env_as_erlang!("VAR")
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues()
    end

    test "as_elixir" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_elixir("VAR")
          Enviable.fetch_env_as_elixir("VAR")
          Enviable.fetch_env_as_elixir!("VAR")
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues()
    end

    test "_as(var, :erlang)" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as("VAR", :erlang)
          Enviable.fetch_env_as("VAR", :erlang)
          Enviable.fetch_env_as!("VAR", :erlang)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues()
    end

    test "_as(var, :elixir)" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as("VAR", :elixir)
          Enviable.fetch_env_as("VAR", :elixir)
          Enviable.fetch_env_as!("VAR", :elixir)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues()
    end

    test "_as(var, {encoded, :erlang})" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as("VAR", {:base64, :erlang})
          Enviable.fetch_env_as("VAR", {:list, :erlang})
          Enviable.fetch_env_as!("VAR", {:base16, :erlang})
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues()
    end

    test "_as(var, {encoded, :elixir})" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as("VAR", {:base64, :elixir})
          Enviable.fetch_env_as("VAR", {:list, :elixir})
          Enviable.fetch_env_as!("VAR", {:url_base64, :elixir})
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues()
    end

    test "as_{encoded}(var, as: :erlang)" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_base64("VAR", as: :erlang)
          Enviable.fetch_env_as_list("VAR", as: :erlang)
          Enviable.fetch_env_as_base16!("VAR", as: :erlang)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues()
    end

    test "as_{encoded}(var, as: :elixir)" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_base32("VAR", as: :elixir)
          Enviable.fetch_env_as_hex32("VAR", as: :elixir)
          Enviable.fetch_env_as_url_base64!("VAR", as: :elixir)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues()
    end

    test "reports when imported" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable

        def some_function do
          get_env_as_erlang("VAR")
          fetch_env_as_elixir!("VAR")
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues()
    end

    test "reports imported generic with :elixir or :erlang type" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable

        def some_function do
          get_env_as("VAR", :erlang)
          fetch_env_as!("VAR", :elixir)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues()
    end
  end
end
