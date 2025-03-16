defmodule Peer2peer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Peer2peerWeb.Telemetry,
      Peer2peer.Repo,
      {DNSCluster, query: Application.get_env(:peer2peer, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Peer2peer.PubSub},
      # Start the Registry for conversation servers
      {Registry, keys: :unique, name: Peer2peer.ConversationRegistry},
      # Start the conversation supervisor
      Peer2peer.Conversations.ConversationSupervisor,
      # Start Presence
      Peer2peerWeb.Presence,
      # Start the Finch HTTP client for sending emails
      {Finch, name: Peer2peer.Finch},
      # Start a worker by calling: Peer2peer.Worker.start_link(arg)
      # {Peer2peer.Worker, arg},
      # Start to serve requests, typically the last entry
      Peer2peerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Peer2peer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Peer2peerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
