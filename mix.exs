defmodule Fluvio.MixProject do
  use Mix.Project

  def project do
    [
      app: :fluvio,
      version: "0.2.4",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      package: package(),
      description: "Elixir client for Fluvio streaming platform",
      source_url: "https://github.com/viniarck/fluvio-ex",
      homepage_url: "https://github.com/viniarck/fluvio-ex",
      docs: [
        main: "Fluvio",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler, "~> 0.30.0"},
      {:excoveralls, "~> 0.15", only: :test},
      {:ex_doc, "~> 0.28.6", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      files:
        ~w(lib native/fluvio_ex/src native/fluvio_ex/Cargo* native/fluvio_ex/.cargo .formatter.exs mix.exs README* LICENSE*
                ),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/viniarck/fluvio-ex",
        "Docs" => "https://hexdocs.pm/fluvio"
      }
    ]
  end
end
