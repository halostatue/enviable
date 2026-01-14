defmodule Enviable.MixProject do
  use Mix.Project

  @app :enviable
  @project_url "https://github.com/halostatue/enviable"
  @version "2.0.0"

  def project do
    [
      app: @app,
      description: "Useful functions for working with environment variables",
      version: @version,
      source_url: @project_url,
      name: "Enviable",
      elixir: "~> 1.17",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      test_coverage: test_coverage(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: [:credo, :mix],
        plt_local_path: "priv/plts/project.plt",
        plt_core_path: "priv/plts/core.plt"
      ]
    ]
  end

  def application do
    [extra_applications: [:logger, :public_key]]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.github": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: "Austin Ziegler",
      licenses: ["Apache-2.0"],
      files: ~w(lib .formatter.exs mix.exs *.md),
      links: %{
        "Source" => @project_url,
        "Issues" => @project_url <> "/issues"
      }
    ]
  end

  defp deps do
    [
      {:nimble_parsec, "~> 1.4"},
      {:decimal, "~> 2.0", optional: true},
      {:jason, "~> 1.0", optional: true},
      {:castore, "~> 1.0", only: [:dev, :test]},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:test]},
      {:ex_doc, "~> 0.29", only: [:dev, :test], runtime: false},
      {:quokka, "~> 2.6", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "Enviable",
      extras: [
        "README.md",
        "CONTRIBUTING.md": [filename: "CONTRIBUTING.md", title: "Contributing"],
        "CODE_OF_CONDUCT.md": [filename: "CODE_OF_CONDUCT.md", title: "Code of Conduct"],
        "CHANGELOG.md": [filename: "CHANGELOG.md", title: "CHANGELOG"],
        "LICENCE.md": [filename: "LICENCE.md", title: "Licence"],
        "licences/APACHE-2.0.txt": [
          filename: "APACHE-2.0.txt",
          title: "Apache License, version 2.0"
        ],
        "licences/dco.txt": [filename: "dco.txt", title: "Developer Certificate of Origin"]
      ],
      source_ref: "v#{@version}",
      source_url: @project_url,
      canonical: "https://hexdocs.pm/#{@app}",
      nest_modules_by_prefix: [Enviable.Credo],
      default_group_for_doc: fn metadata ->
        if group = metadata[:group], do: "Functions: #{group}"
      end
    ]
  end

  defp test_coverage do
    [
      tool: ExCoveralls
    ]
  end
end
