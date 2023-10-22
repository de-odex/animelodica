defmodule Animelodica.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AnimelodicaWeb.Telemetry,
      Animelodica.Repo,
      {DNSCluster, query: Application.get_env(:animelodica, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Animelodica.PubSub},
      # Start a worker by calling: Animelodica.Worker.start_link(arg)
      # {Animelodica.Worker, arg},
      # Start to serve requests, typically the last entry
      AnimelodicaWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Animelodica.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AnimelodicaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
