defmodule Peer2peerWeb.ConversationLive.Settings do
  use Peer2peerWeb, :live_view

  alias Peer2peer.Conversations
  alias Peer2peer.Conversations.{Conversation, ConversationServer, AIParticipant}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    conversation_id = String.to_integer(id)
    conversation = Conversations.get_conversation_with_participants!(conversation_id)
    ai_participants = Conversations.list_ai_participants(conversation)

    # Subscribe to conversation updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Peer2peer.PubSub, "conversation:#{conversation_id}")
    end

    socket =
      socket
      |> assign(:page_title, "Settings - #{conversation.title}")
      |> assign(:conversation, conversation)
      |> assign(:ai_participants, ai_participants)
      |> assign(
        :conversation_form,
        to_form(%{
          "title" => conversation.title,
          "description" => conversation.description
        })
      )
      |> assign(
        :ai_form,
        to_form(%{
          "name" => "",
          "provider" => "openai",
          "model" => "gpt-4-turbo",
          "persona" => "",
          "system_prompt" => ""
        })
      )

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "update_conversation",
        %{"title" => title, "description" => description},
        socket
      ) do
    case Conversations.update_conversation(socket.assigns.conversation, %{
           "title" => title,
           "description" => description
         }) do
      {:ok, updated_conversation} ->
        socket =
          socket
          |> assign(:conversation, updated_conversation)
          |> put_flash(:info, "Conversation updated successfully.")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> assign(:conversation_form, to_form(changeset))
          |> put_flash(:error, "Error updating conversation.")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_ai_participant", params, socket) do
    # Extract AI participant parameters
    ai_params = Map.take(params, ["name", "provider", "model", "persona", "system_prompt"])

    # Create AI participant
    case Conversations.create_ai_participant(ai_params, socket.assigns.conversation) do
      {:ok, ai_participant} ->
        ai_participants = [ai_participant | socket.assigns.ai_participants]

        socket =
          socket
          |> assign(:ai_participants, ai_participants)
          |> assign(
            :ai_form,
            to_form(%{
              "name" => "",
              "provider" => "openai",
              "model" => "gpt-4-turbo",
              "persona" => "",
              "system_prompt" => ""
            })
          )
          |> put_flash(:info, "AI participant added successfully.")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> assign(:ai_form, to_form(changeset))
          |> put_flash(:error, "Error adding AI participant.")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("advance_phase", _params, socket) do
    # Ensure conversation server is running
    Peer2peer.Conversations.ConversationSupervisor.ensure_conversation_server(
      socket.assigns.conversation.id
    )

    # Send advance phase command to the conversation server
    ConversationServer.advance_phase(socket.assigns.conversation.id)

    {:noreply, put_flash(socket, :info, "Advancing to next phase...")}
  end

  @impl true
  def handle_event("update_progress", %{"progress" => progress_str}, socket) do
    progress = String.to_float(progress_str)

    # Ensure conversation server is running
    Peer2peer.Conversations.ConversationSupervisor.ensure_conversation_server(
      socket.assigns.conversation.id
    )

    # Send update progress command to the conversation server
    ConversationServer.update_phase_progress(socket.assigns.conversation.id, progress)

    {:noreply, put_flash(socket, :info, "Progress updated.")}
  end

  @impl true
  def handle_event("remove_ai", %{"id" => id}, socket) do
    ai_id = String.to_integer(id)
    ai_participant = Enum.find(socket.assigns.ai_participants, &(&1.id == ai_id))

    case Conversations.delete_ai_participant(ai_participant) do
      {:ok, _} ->
        socket =
          socket
          |> assign(
            :ai_participants,
            Enum.reject(socket.assigns.ai_participants, &(&1.id == ai_id))
          )
          |> put_flash(:info, "AI participant removed.")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error removing AI participant.")}
    end
  end

  @impl true
  def handle_info({:phase_changed, updated_conversation}, socket) do
    {:noreply, assign(socket, conversation: updated_conversation)}
  end

  @impl true
  def handle_info({:phase_progress_updated, updated_conversation}, socket) do
    {:noreply, assign(socket, conversation: updated_conversation)}
  end
end
