defmodule Peer2peerWeb.Show do
  use Peer2peerWeb, :live_view

  alias Peer2peer.Conversations
  alias Peer2peer.Conversations.{Conversation, Message, ConversationServer}
  alias Peer2peerWeb.Presence

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    conversation_id = String.to_integer(id)

    if connected?(socket) do
      # Subscribe to the conversation's PubSub topic
      Phoenix.PubSub.subscribe(Peer2peer.PubSub, "conversation:#{conversation_id}")

      # Ensure a conversation server is running
      Peer2peer.Conversations.ConversationSupervisor.ensure_conversation_server(conversation_id)

      # Track user presence in this conversation
      Presence.track_user_in_conversation(
        conversation_id,
        socket.assigns.current_user.id,
        %{
          username: socket.assigns.current_user.email,
          online_at: DateTime.utc_now()
        }
      )
    end

    conversation = Conversations.get_conversation_with_participants!(conversation_id)
    messages = Conversations.list_messages(conversation, limit: 20)
    ai_participants = Conversations.list_ai_participants(conversation)

    # Get presence information
    presences = Presence.list_users_in_conversation(conversation_id)

    socket =
      socket
      |> assign(:page_title, conversation.title)
      |> assign(:conversation, conversation)
      |> assign(:messages, messages)
      |> assign(:ai_participants, ai_participants)
      |> assign(:message_form, to_form(%{"content" => ""}))
      |> assign(:presences, presences)
      |> assign(:typing_users, [])

    {:ok, socket}
  end

  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    %{conversation: conversation, current_user: current_user} = socket.assigns

    # Create a new message
    {:ok, message} =
      Conversations.create_message(%{
        user: current_user,
        conversation: conversation,
        content: content
      })

    # Notify the conversation server about the new message
    ConversationServer.add_message(conversation.id, message)

    # Potentially trigger AI response
    if should_trigger_ai_response?(socket) do
      send(self(), {:generate_ai_response, message})
    end

    socket =
      socket
      |> assign(:message_form, to_form(%{"content" => ""}))
      |> update(:messages, fn messages -> [message | messages] end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("typing", _params, socket) do
    typing_event = %{
      user_id: socket.assigns.current_user.id,
      username: socket.assigns.current_user.email
    }

    # Broadcast typing event to other users
    Phoenix.PubSub.broadcast(
      Peer2peer.PubSub,
      "conversation:#{socket.assigns.conversation.id}",
      {:user_typing, typing_event}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    # Handle incoming messages from other users
    updated_messages = [message | socket.assigns.messages]

    # Remove from typing users if this user was typing
    typing_users =
      Enum.reject(socket.assigns.typing_users, fn user ->
        user.id == message.user_id
      end)

    {:noreply, assign(socket, messages: updated_messages, typing_users: typing_users)}
  end

  @impl true
  def handle_info({:user_typing, typing_event}, socket) do
    # Don't show typing indicator for current user
    if typing_event.user_id != socket.assigns.current_user.id do
      # Add user to typing list if not already there
      typing_users =
        if Enum.any?(socket.assigns.typing_users, fn user -> user.id == typing_event.user_id end) do
          socket.assigns.typing_users
        else
          [typing_event | socket.assigns.typing_users]
        end

      # Set a timer to remove typing indicator after 3 seconds
      Process.send_after(self(), {:remove_typing_indicator, typing_event.user_id}, 3000)

      {:noreply, assign(socket, typing_users: typing_users)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:remove_typing_indicator, user_id}, socket) do
    typing_users = Enum.reject(socket.assigns.typing_users, fn user -> user.id == user_id end)
    {:noreply, assign(socket, typing_users: typing_users)}
  end

  @impl true
  def handle_info({:phase_changed, updated_conversation}, socket) do
    {:noreply, assign(socket, conversation: updated_conversation)}
  end

  @impl true
  def handle_info({:phase_progress_updated, updated_conversation}, socket) do
    {:noreply, assign(socket, conversation: updated_conversation)}
  end

  @impl true
  def handle_info({:generate_ai_response, triggering_message}, socket) do
    # Pick the first available AI participant for now
    # In a more complex implementation, you'd determine which AI should respond
    case socket.assigns.ai_participants do
      [ai | _] ->
        # Start generating AI response asynchronously
        send(self(), {:start_ai_typing, ai})

        Task.async(fn ->
          # Get conversation history for context
          history = prepare_conversation_history(socket.assigns.messages, triggering_message)

          # Generate the AI response
          {:ok, response} = Peer2peer.AI.generate_response(history, provider: ai.provider)

          # Create the AI message
          Conversations.create_ai_message(%{
            ai_participant: ai,
            conversation: socket.assigns.conversation,
            content: response.content
          })
        end)

      [] ->
        # No AI participants available
        nil
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:start_ai_typing, ai}, socket) do
    # Simulate AI typing indicator
    typing_event = %{
      user_id: "ai-#{ai.id}",
      username: "#{ai.name} (AI)",
      is_ai: true
    }

    # Add AI to typing users
    typing_users = [typing_event | socket.assigns.typing_users]

    {:noreply, assign(socket, typing_users: typing_users)}
  end

  @impl true
  def handle_info({_ref, {:ok, ai_message}}, socket) do
    # AI message created successfully, update the UI
    # Remove AI from typing users
    typing_users =
      Enum.reject(socket.assigns.typing_users, fn user ->
        Map.get(user, :is_ai, false) == true
      end)

    updated_messages = [ai_message | socket.assigns.messages]

    {:noreply, assign(socket, messages: updated_messages, typing_users: typing_users)}
  end

  # If a Task crashes, we get a DOWN message
  @impl true
  def handle_info({:DOWN, _, :process, _, _}, socket) do
    # Task completed or crashed, make sure typing indicator is removed
    typing_users =
      Enum.reject(socket.assigns.typing_users, fn user ->
        Map.get(user, :is_ai, false) == true
      end)

    {:noreply, assign(socket, typing_users: typing_users)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    presences = Presence.list_users_in_conversation(socket.assigns.conversation.id)
    {:noreply, assign(socket, presences: presences)}
  end

  # Helper functions

  defp should_trigger_ai_response?(socket) do
    # Simple implementation: respond if there's at least one AI participant
    length(socket.assigns.ai_participants) > 0
  end

  defp prepare_conversation_history(messages, latest_message) do
    # Placeholder for preparing conversation history for AI
    # In a real implementation, you'd format the messages properly for your AI service
    # and potentially limit the history to fit within context windows
    [latest_message | Enum.take(messages, 10)]
    |> Enum.reverse()
    |> Enum.map(fn msg ->
      %{
        role: if(msg.is_ai_generated, do: "assistant", else: "user"),
        content: msg.content
      }
    end)
  end
end
