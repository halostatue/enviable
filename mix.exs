defmodule Enviable.MixProject do
  use Mix.Project

  def project do
    [
      app: :enviable,
      version: "1.2.1",
      description: "Useful functions for working with environment variables",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Enviable",
      source_url: "https://github.com/halostatue/enviable",
      docs: [
        main: "Enviable",
        extras: [
          "Contributing.md",
          "Code-of-Conduct.md": [filename: "Code-of-Conduct.md", title: "Code of Conduct"],
          "Changelog.md": [filename: "Changelog.md", title: "CHANGELOG"],
          "Licence.md": [filename: "Licence.md", title: "Licence"],
          "licences/APACHE-2.0.txt": [
            filename: "APACHE-2.0.txt",
            title: "Apache License, version 2.0"
          ],
          "licences/dco.txt": [filename: "dco.txt", title: "Developer Certificate of Origin"]
        ]
      ],
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

  defp elixirc_paths(:test) do
    ~w(lib test/support)
  end

  defp elixirc_paths(_) do
    ~w(lib)
  end
end
