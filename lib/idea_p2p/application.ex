defmodule IdeaP2p.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      IdeaP2pWeb.Telemetry,
      IdeaP2p.Repo,
      {DNSCluster, query: Application.get_env(:idea_p2p, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: IdeaP2p.PubSub},
      # Start Presence
      IdeaP2pWeb.Presence,
      # Start the Finch HTTP client for sending emails
      {Finch, name: IdeaP2p.Finch},
      # Start a worker by calling: IdeaP2p.Worker.start_link(arg)
      # {IdeaP2p.Worker, arg},
      # Start to serve requests, typically the last entry
      IdeaP2pWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: IdeaP2p.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    IdeaP2pWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
