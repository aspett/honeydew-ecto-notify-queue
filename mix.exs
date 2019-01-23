defmodule HoneydewEctoNotifyQueue.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :honeydew_ecto_notify_queue,
      version: @version,
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Ecto postgres notifications-based queue for Honeydew",
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:ecto, "~> 3.0", override: true},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, "~> 0.14"},
      {:poison, "~> 3.1"},
      {:honeydew, "~> 1.1.5"},
      {:jason, "~> 1.1"},
    ]
  end

  defp package do
    [maintainers: ["Andrew Pett"],
     licenses: ["MIT"],
     links: %{"GitHub": "https://github.com/aspett/honeydew-ecto-notify-queue"}]
  end

  defp docs do
    [extras: ["README.md"],
     source_url: "https://github.com/aspett/honeydew-ecto-notify-queue",
     assets: "assets",
     main: "readme",
     source_ref: @version]
  end

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
