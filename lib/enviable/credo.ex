if Code.ensure_loaded?(Credo) do
  defmodule Enviable.Credo do
    @moduledoc """
    Credo checks for Enviable and Enviable.Codex.

    This plugin provides Enviable.Credo.UnsafeAtom and Enviable.Credo.UnsafeEval
    to detect possible misuse of the dangerous conversions provided by Enviable.

    Add this to your `.credo.exs`:

    ```elixir
    %{
      configs: [
        %{name: "default", plugins: [{Enviable.Credo, []}]}
      ]
    }
    ```
    """

    import Credo.Plugin

    @config_file """
    %{
      configs: [
        %{
          name: "default",
          checks: %{
            extra: [
              {Enviable.Credo.UnsafeAtom, []},
              {Enviable.Credo.UnsafeEval, []}
            ]
          }
        }
      ]
    }
    """

    @doc false
    def init(exec) do
      register_default_config(exec, @config_file)
    end
  end
end
