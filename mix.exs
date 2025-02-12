defmodule Enviable.MixProject do
  use Mix.Project

  def project do
    [
      app: :enviable,
      version: "1.3.0",
      description: "Useful functions for working with environment variables",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Enviable",
      source_url: "https://github.com/halostatue/enviable",
      docs: docs(),
      package: [
        files: ~w(lib .formatter.exs mix.exs *.md),
        licenses: ["Apache-2.0"],
        links: %{
          "Source" => "https://github.com/halostatue/enviable",
          "Issues" => "https://github.com/halostatue/enviable/issues"
        }
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: [:mix],
        plt_local_path: "priv/plts/project.plt",
        plt_core_path: "priv/plts/core.plt"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :public_key]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.0", optional: true},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.29", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.2", only: [:dev, :test], runtime: false}
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
      default_group_for_doc: fn metadata ->
        if group = metadata[:group], do: "Functions: #{group}"
      end
    ]
  end

  defp elixirc_paths(:test) do
    ~w(lib test/support)
  end

  defp elixirc_paths(_) do
    ~w(lib)
  end
end
