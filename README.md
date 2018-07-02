# HoneydewEctoNotifyQueue

[![Build Status](https://travis-ci.org/aspett/honeydew-ecto-notify-queue.svg?branch=master)](https://travis-ci.org/aspett/honeydew-ecto-notify-queue)

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [HoneydewEctoNotifyQueue](#honeydewectonotifyqueue)
    - [Description](#description)
    - [Notes](#notes)
    - [Setting it up](#setting-it-up)
        - [Installing](#installing)
        - [Generating the postgres migration](#generating-the-postgres-migration)
        - [Starting the queue](#starting-the-queue)
    - [Running the tests](#running-the-tests)
    - [Custom job configuration persistence](#custom-job-configuration-persistence)

<!-- markdown-toc end -->

## Description

HoneydewEctoNotifyQueue is a queue built for [Honeydew](https://github.com/koudelka/honeydew) that uses postgres notifications
instead of polling. It was originally built before honeydew offered the ecto polling solution.

Contrary to the honeydew ecto polling solution, this package sets up two independent tables for managing
the queue of jobs, and managing configuration over multiple instances;

A `jobs` table tracks jobs and `job_configs` table tracks configurations.

## Notes

**`Honeydew.yield` is not supported by this adapter.**

Jobs are reserved using postgres' `FOR UPDATE NOWAIT` locking.

It is possible to suspend _all_ job processing across instances by updating the `suspended` job config;

```elixir
{:ok, _config} = HoneydewEctoNotifyQueue.Config.update_config(MyApp.Repo, "suspended", "true")
```

See more about configuration handling [here](#custom-job-configuration-persistence)

## Setting it up

### Installing
The package is available on hex.pm [here.](https://hex.pm/packages/honeydew_ecto_notify_queue)

You can add it to your mix.exs,

```elixir
defp deps do
  [
    # ..,
    {:honeydew, "~> 1.1.5"},
    {:honeydew_ecto_notify_queue, "~> 0.1"}
  ]
end
```

### Generating the postgres migration

You can generate a migration to set up the required db tables with

```bash
$ mix honeydew_ecto_notify_queue.db.gen.migration
```

### Starting the queue

Note: You should read [how to install honeydew here first](https://github.com/koudelka/honeydew)

This queue takes some additional options. An example below,

```elixir
import Supervisor.Spec

def background_job_processes do
  [
    notifier_process(),
    Honeydew.queue_spec(:process, # queue_name
      queue: {HoneydewEctoNotifyQueue, [
                  repo: YourApp.Repo, # your app's Repo module
                  max_job_time: 3_600, # seconds
                  retry_seconds: 15, # seconds,
                  notifier: YourApp.Notifier # this should match the `name:` in `notifier_process` below
                ]},
      failure_mode: {Honeydew.FailureMode.Retry, times: 3}
    ),
    Honeydew.worker_spec(:process, YourApp.Worker, num: 1)
  ]
end

def notifier_process do
  worker(Postgrex.Notifications, [YourApp.Repo.config() ++ [name: YourApp.Notifier]])
end

def start(_type, _args) do
  children = [
    # ... The rest of your app's supervision tree
  ] ++ background_job_processes
  
  Supervisor.start_link(children, opts)
end
```

## Running the tests

```bash
$ MIX_ENV=test mix do ecto.create, ecto.migrate
$ mix test
```

## Custom job configuration persistence
This queue also adds support for persisting job configuration state via postgres.
By default, this is how queue suspension is managed across multiple instances.

You can leverage the existing notification setup to synchronise other configurations
across instances.

An example of this may be the disabling of automatic queuing of a job when an API is hit.

You can see an example of how to listen for configuration changes in 
`examples/configuration_listener.ex`
