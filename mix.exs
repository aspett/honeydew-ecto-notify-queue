defmodule HoneydewEctoNotifyQueue.MixProject do
  use Mix.Project

  def project do
    [
      app: :honeydew_ecto_notify_queue,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
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
      {:ecto, "~> 2.2"},
      {:postgrex, "~> 0.13"},
      {:poison, "~> 3.1"},
      {:honeydew, git: "https://github.com/aspett/honeydew.git", branch: "new-supervisor-spec"}
    ]
  end
end
