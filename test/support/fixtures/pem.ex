defmodule Enviable.Fixtures.PEM do
  @moduledoc """
  PEM Fixtures resolver.
  """

  paths = Path.wildcard("test/fixtures/*.pem")
  @paths_hash :erlang.md5(paths)

  for path <- paths, do: @external_resource(path)

  @pem_fixtures Map.new(paths, &{Path.basename(&1, ".pem"), &1})

  def __mix_recompile__?, do: :erlang.md5(Path.wildcard("test/fixtures/*.pem")) != @paths_hash

  def load_pem!(name) do
    name
    |> pem_fixture()
    |> File.read!()
  end

  def pem_fixture(name), do: @pem_fixtures[name]
end
