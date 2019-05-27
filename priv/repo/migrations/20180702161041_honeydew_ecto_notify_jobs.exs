defmodule HoneydewEctoNotifyQueue.Repo.Migrations.CreateHoneydewEctoNotifyTables do
  use Ecto.Migration

  def up do
    create table(:jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :queue, :string
      add :function, :string
      add :arguments, :jsonb
      add :failure_state, :jsonb
      add :reserved_at, :utc_datetime_usec
      add :nacked_until, :utc_datetime_usec
      add :acked_at, :utc_datetime_usec
      add :abandoned_at, :utc_datetime_usec

      timestamps()
    end

    create index(:jobs, [:reserved_at, :acked_at, :nacked_until], using: :btree)
    create index(:jobs, :queue, using: :btree)
    create index(:jobs, :inserted_at, using: :btree)

    create table(:job_configs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :value, :string, null: false

      timestamps()
    end

    create unique_index(:job_configs, [:key], using: :btree)

    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""
    execute "INSERT INTO job_configs VALUES (uuid_generate_v4(), 'suspended', false, now(), now())"

    execute """
      CREATE FUNCTION f_notify_config_change()
      RETURNS trigger AS $$
      DECLARE
      BEGIN
        PERFORM pg_notify(TG_TABLE_NAME, 'config_update');
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
    """

    execute """
      CREATE FUNCTION f_notify_new_job()
      RETURNS trigger AS $$
      DECLARE
      BEGIN
        PERFORM pg_notify(TG_TABLE_NAME, 'new_job');
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
    """

    execute """
      CREATE TRIGGER t_notify_config_change
      AFTER UPDATE ON job_configs
      FOR EACH ROW
      EXECUTE PROCEDURE f_notify_config_change();
    """

    execute """
      CREATE TRIGGER t_notify_new_job
      AFTER INSERT ON jobs
      FOR EACH ROW
      EXECUTE PROCEDURE f_notify_new_job();
    """
  end

  def down do
    execute "DROP TRIGGER t_notify_config_change ON job_configs"
    execute "DROP FUNCTION f_notify_config_change()"
    execute "DROP TRIGGER t_notify_new_job ON jobs"
    execute "DROP FUNCTION f_notify_new_job()"

    drop_if_exists table(:jobs)
    drop_if_exists table(:job_configs)
  end
end
