defmodule Mix.Tasks.HoneydewEctoNotifyQueue.Db.Gen.Migration do
  @moduledoc """
  Generates a migration for HoneydewEctoNotifyQueue's jobs and configuration tables.
  """

  @shortdoc @moduledoc

  # Based off Guardian's mix task for generating a migration found at
  # https://github.com/ueberauth/guardian_db/blob/master/lib/mix/tasks/guardian_db.gen.migration.ex

  use Mix.Task

  import Mix.Ecto
  import Mix.Generator

  @doc false
  def run(args) do
    no_umbrella!("ecto.gen.migration")

    repos = parse_repo(args)

    Enum.each(repos, fn repo ->
      ensure_repo(repo, args)
      path = Ecto.Migrator.migrations_path(repo)

      source_path =
        :honeydew_ecto_notify_queue
        |> Application.app_dir()
        |> Path.join("priv/templates/migration.exs.eex")

      generated_file = EEx.eval_file(source_path, module_prefix: app_module())

      target_file = Path.join(path, "#{timestamp()}_honeydew_ecto_notify_jobs.exs")

      create_directory(path)
      create_file(target_file, generated_file)
    end)
  end

  defp app_module do
    Mix.Project.config()
    |> Keyword.fetch!(:app)
    |> to_string()
    |> Macro.camelize()
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)
end
