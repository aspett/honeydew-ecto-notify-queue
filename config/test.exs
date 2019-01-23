use Mix.Config

config :logger, level: :warn

config :honeydew_ecto_notify_queue, ecto_repos: [HoneydewEctoNotifyQueue.Repo]

config :honeydew_ecto_notify_queue, HoneydewEctoNotifyQueue.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("DATABASE_URL") || "${DATABASE_URL}",
  pool: Ecto.Adapters.SQL.Sandbox
