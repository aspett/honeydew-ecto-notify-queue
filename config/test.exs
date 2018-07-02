use Mix.Config

config :logger, level: :warn

config :honeydew_ecto_notify_queue, ecto_repos: [HoneydewEctoNotifyQueue.Repo]

config :honeydew_ecto_notify_queue, HoneydewEctoNotifyQueue.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "honeydew_ecto_notify_queue_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
