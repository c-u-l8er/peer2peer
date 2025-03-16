defmodule Peer2peer.Conversations.ConversationServer do
  @moduledoc """
  GenServer for managing a conversation's state, handling phase transitions,
  and coordinating real-time updates.
  """

  use GenServer
  require Logger
  alias Peer2peer.Conversations
  alias Peer2peer.Conversations.Conversation
  alias Peer2peer.PubSub

  # Client API

  def start_link(id) when is_integer(id) do
    GenServer.start_link(__MODULE__, id, name: via_tuple(id))
  end

  def get_state(id) do
    GenServer.call(via_tuple(id), :get_state)
  end

  def update_phase_progress(id, progress) do
    GenServer.cast(via_tuple(id), {:update_progress, progress})
  end

  def advance_phase(id) do
    GenServer.cast(via_tuple(id), :advance_phase)
  end

  def add_message(id, message) do
    GenServer.cast(via_tuple(id), {:add_message, message})
  end

  def via_tuple(id) do
    {:via, Registry, {Peer2peer.ConversationRegistry, id}}
  end

  # Server Callbacks

  @impl true
  def init(id) do
    Logger.info("Starting conversation server for conversation ##{id}")

    # Load the conversation from the database
    conversation = Conversations.get_conversation!(id)

    # Subscribe to the conversation's topic
    Phoenix.PubSub.subscribe(PubSub, "conversation:#{id}")

    {:ok,
     %{
       id: id,
       conversation: conversation,
       last_activity: DateTime.utc_now()
     }}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:update_progress, progress}, state) do
    %{id: id, conversation: conversation} = state

    # Update the conversation's phase progress
    {:ok, updated_conversation} = Conversations.update_phase_progress(conversation, progress)

    # Broadcast the change
    Phoenix.PubSub.broadcast(
      PubSub,
      "conversation:#{id}",
      {:phase_progress_updated, updated_conversation}
    )

    {:noreply, %{state | conversation: updated_conversation, last_activity: DateTime.utc_now()}}
  end

  @impl true
  def handle_cast(:advance_phase, state) do
    %{id: id, conversation: conversation} = state

    # Determine the next phase
    next_phase = next_mitosis_phase(conversation.mitosis_phase)

    # Update the conversation's phase
    {:ok, updated_conversation} =
      Conversations.change_conversation_phase(conversation, next_phase)

    # Broadcast the change
    Phoenix.PubSub.broadcast(
      PubSub,
      "conversation:#{id}",
      {:phase_changed, updated_conversation}
    )

    {:noreply, %{state | conversation: updated_conversation, last_activity: DateTime.utc_now()}}
  end

  @impl true
  def handle_cast({:add_message, message}, state) do
    %{id: id} = state

    # Broadcast the new message
    Phoenix.PubSub.broadcast(
      PubSub,
      "conversation:#{id}",
      {:new_message, message}
    )

    {:noreply, %{state | last_activity: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:new_message, _message}, state) do
    # Handle incoming message, potentially updating phase progress
    # based on conversation analysis (will be implemented later)
    {:noreply, state}
  end

  # Helper functions

  defp next_mitosis_phase(:prophase), do: :prometaphase
  defp next_mitosis_phase(:prometaphase), do: :metaphase
  defp next_mitosis_phase(:metaphase), do: :anaphase
  defp next_mitosis_phase(:anaphase), do: :telophase
  # Cycle back for now
  defp next_mitosis_phase(:telophase), do: :prophase
end
