defmodule Peer2peer.Conversations.ConversationSupervisor do
  @moduledoc """
  Supervises individual conversation servers, allowing for dynamic creation
  and management of conversation processes.
  """

  use DynamicSupervisor

  alias Peer2peer.Conversations.ConversationServer

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Ensures a conversation server is running for the given conversation ID
  """
  def ensure_conversation_server(conversation_id) do
    case Registry.lookup(Peer2peer.ConversationRegistry, conversation_id) do
      [] ->
        # No existing process, start a new one
        DynamicSupervisor.start_child(__MODULE__, {ConversationServer, conversation_id})

      [{pid, _}] ->
        # Process already exists
        {:ok, pid}
    end
  end

  @doc """
  Stops a conversation server for the given conversation ID
  """
  def stop_conversation_server(conversation_id) do
    case Registry.lookup(Peer2peer.ConversationRegistry, conversation_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        {:error, :not_found}
    end
  end
end
