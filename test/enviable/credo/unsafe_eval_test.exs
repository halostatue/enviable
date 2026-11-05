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

    test "ignores non-atom / module conversions" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as_base64("VAR", as: :integer)
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

    test "reports piped Enviable calls" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable

        def some_function do
          "VAR" |> Enviable.get_env_as(:erlang)
          "VAR" |> get_env_as_elixir()
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues(2)
    end

    test "reports {encoded, type} with the tuple in the message" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.get_env_as("VAR", {:base64, :elixir})
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issue(fn issue ->
        assert issue.message ==
                 "Enviable.get_env_as(..., {:base64, :elixir}) evaluates arbitrary code from environment variables."
      end)
    end
  end

  describe "Enviable.Codex: no issues reported" do
    test "other conversions" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable.Codex

        def some_function do
          get_env("VAR") |> as_atom()
          get_env("VAR") |> as(:json)
          get_env("VAR") |> as_base64(as: :string)
          Enviable.Codex.as(get_env("VAR"), {:base64, :integer})
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> refute_issues()
    end

    test "bare as_* calls without import Enviable.Codex" do
      ~S'''
      defmodule CredoSampleModule do
        def as_erlang(value), do: value

        def some_function do
          as_erlang("VAR")
          "VAR" |> as_erlang()
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> refute_issues()
    end
  end

  describe "Enviable.Codex: issues reported" do
    test "remote calls" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function(value) do
          Enviable.Codex.as_erlang(value)
          Enviable.Codex.as_elixir(value)
          Enviable.Codex.as(value, :erlang)
          Enviable.Codex.as(value, {:base64, :elixir})
          Enviable.Codex.as_hex32(value, as: :erlang)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues(5)
    end

    test "piped remote calls" do
      ~S'''
      defmodule CredoSampleModule do
        def some_function do
          Enviable.Codex.get_env("VAR") |> Enviable.Codex.as_erlang()
          "VAR" |> Enviable.Codex.get_env() |> Enviable.Codex.as(:elixir)
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues(2)
    end

    test "imported calls" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable.Codex

        def some_function do
          get_env("VAR") |> as_elixir()
          fetch_env!("VAR") |> as({:url_base64, :erlang})
          fetch_env!("VAR") |> as_base64(as: :elixir)
          as_erlang(get_env("VAR"))
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues(4)
    end

    test "both modules imported" do
      ~S'''
      defmodule CredoSampleModule do
        import Enviable
        import Enviable.Codex

        def some_function do
          get_env_as_erlang("VAR")
          get_env("VAR") |> as_elixir()
        end
      end
      '''
      |> to_source_file()
      |> run_check(UnsafeEval)
      |> assert_issues(2)
    end
  end
end

defmodule Enviable.Credo.UnsafeEvalAliasTest do
  use Credo.Test.Case

  alias Enviable.Credo.UnsafeEval

  test "reports calls through aliases" do
    ~S'''
    defmodule CredoSampleModule do
      alias Enviable, as: E
      alias Enviable.{Codex}
      alias Enviable.Codex, as: C

      def some_function(value) do
        Codex.as_erlang(value)
        value |> C.as({:base64, :elixir})
        E.get_env_as_elixir("VAR")
      end
    end
    '''
    |> to_source_file()
    |> run_check(UnsafeEval)
    |> assert_issues(3)
  end

  test "ignores shadowed aliases" do
    ~S'''
    defmodule CredoSampleModule do
      alias Enviable.Codex
      alias MyApp.Codex

      def some_function(value) do
        Codex.as_erlang(value)
      end
    end
    '''
    |> to_source_file()
    |> run_check(UnsafeEval)
    |> refute_issues()
  end
end
