defmodule HoneydewEctoNotifyQueue.Config do
  @moduledoc """
  Module for managing auxiliary job configurations
  """

  alias HoneydewEctoNotifyQueue.JobConfig
  alias Ecto.Repo

  @doc """
  Fetches all job configuration records using the given repo
  """
  @spec list_configs(Repo.t()) :: {:ok, list(JobConfig.t())}
  def list_configs(repo) do
    {:ok, repo.all(JobConfig)}
  end

  @doc """
  Fetches a single job config using the given repo for the specified key
  """
  @spec get_config(Repo.t(), String.t()) :: {:ok, JobConfig.t()} | {:error, :not_found}
  def get_config(repo, key) do
    case repo.get_by(JobConfig, key: key) do
      nil -> {:error, :not_found}
      config -> {:ok, config}
    end
  end

  @doc """
  Creates a job config using the given repo

  Note: value must be a string.
  """
  @spec create_config(Repo.t(), String.t(), String.t()) :: {:ok, JobConfig.t()} | {:error, any}
  def create_config(repo, key, value) when is_binary(value) do
    %JobConfig{}
    |> JobConfig.changeset(%{key: key, value: value})
    |> repo.insert()
  end

  def create_config(_repo, _key, _value) do
    {:error, :invalid_value}
  end

  @doc """
  Updates a job config using the given repo

  Note: value must be a string.

  Example:

      iex> job_config = get_config(Repo, "queuing_mode")
      iex> update_config(Repo, job_config, "manual")
      {:ok, %JobConfig{}}

      iex> update_config(Repo, "queueing_mode", "manual")
      {:ok, %JobConfig{}}
  """
  @spec update_config(Repo.t(), JobConfig.t() | String.t(), String.t()) :: {:ok, JobConfig.t()} | {:error, any}
  def update_config(repo, %JobConfig{} = config, value) when is_binary(value) do
    config
    |> JobConfig.changeset(%{value: value})
    |> repo.update()
  end

  def update_config(repo, key, value) when is_binary(key) and is_binary(value) do
    with {:ok, config} <- get_config(repo, key) do
      update_config(repo, config, value)
    end
  end

  def update_config(_repo, _config, _value) do
    {:error, :invalid_value}
  end

  @doc """
  Deletes a job config using the given repo. Takes either a JobConfig or config key.

  Examples:

      iex> delete_config(Repo, %JobConfig{id: 1, key: "config"})
      {:ok, %JobConfig{}}

      iex> delete_config(Repo, "config")
      {:ok, %JobConfig{}}
  """
  @spec delete_config(Repo.t(), JobConfig.t()) :: {:ok, JobConfig.t()} | {:error, any}
  def delete_config(repo, %JobConfig{} = config) do
    repo.delete(config)
  end

  @spec delete_config(Repo.t(), String.t()) :: {:ok, JobConfig.t()} | {:error, any}
  def delete_config(repo, key) do
    with {:ok, config} <- get_config(repo, key) do
      repo.delete(config)
    end
  end
end
