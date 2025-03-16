defmodule Peer2peerWeb.ConversationLive.Show do
  use Peer2peerWeb, :live_view

  alias Peer2peer.Conversations

  alias Peer2peer.Conversations.{
    Conversation,
    ConversationParticipant,
    Message,
    AIParticipant,
    ConversationRelationship,
    Topic,
    ConversationTopic
  }

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

    {:ok, conversation} =
      try do
        {:ok, Conversations.get_conversation_with_participants!(conversation_id)}
      rescue
        _ ->
          {:error, :not_found}
      end

    case conversation do
      # Match the Conversation struct itself
      %Conversation{} = conversation ->
        messages = Conversations.list_messages(conversation, limit: 20)

        # Preload is already done, so use them directly
        participants = conversation.participants
        ai_participants = conversation.ai_participants

        # Get presence information
        presences = Presence.list_users_in_conversation(conversation_id)

        socket =
          socket
          |> assign(:page_title, conversation.title)
          |> assign(:conversation, conversation)
          |> assign(:messages, messages)
          |> assign(:ai_participants, ai_participants)
          # Add participants
          |> assign(:participants, participants)
          |> assign(:message_form, to_form(%{"content" => ""}))
          |> assign(:presences, presences)
          |> assign(:typing_users, [])
          |> assign(:reset_input, false)

        {:ok, socket}

      :not_found ->
        {:ok,
         socket
         |> put_flash(:error, "Conversation not found.")
         |> redirect(to: ~p"/conversations")}
    end
  end

  def handle_event("typing", %{"value" => content}, socket) do
    if String.trim(content) != "" do
      # Broadcast typing status to all users in the conversation
      conversation_id = socket.assigns.conversation.id
      user_id = socket.assigns.current_user.id
      username = socket.assigns.current_user.email

      typing_event = %{
        user_id: user_id,
        username: username,
        is_ai: false
      }

      Phoenix.PubSub.broadcast(
        Peer2peer.PubSub,
        "conversation:#{conversation_id}",
        {:user_typing, typing_event}
      )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    {:noreply, socket} = handle_send_message(content, socket)
    {:noreply, socket}
  end

  defp handle_send_message(content, socket) do
    %{conversation: conversation, current_user: current_user} = socket.assigns

    # Create a new message - make sure we're using the fully qualified module name
    case Peer2peer.Conversations.create_message(%{
           user: current_user,
           conversation: conversation,
           content: content
         }) do
      {:ok, message} ->
        # Notify the conversation server about the new message
        Peer2peer.Conversations.ConversationServer.add_message(conversation.id, message)

        # Potentially trigger AI response
        if should_trigger_ai_response?(socket) do
          send(self(), {:generate_ai_response, message})
        end

        socket =
          socket
          |> assign(:message_form, to_form(%{"content" => ""}))
          |> assign(:reset_input, true)
          |> update(:messages, fn messages ->
            # Only add message if it doesn't already exist
            if Enum.any?(messages, fn m -> m.id == message.id end) do
              messages
            else
              [message | messages]
            end
          end)

        # Reset the reset_input flag after a short delay
        Process.send_after(self(), :reset_input_flag, 100)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to send message.")
         |> assign(:message_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_info(:submit_message, socket) do
    # Get the message content from the form
    content = socket.assigns.message_form.params["content"]

    if String.trim(content) != "" do
      send(self(), {:send_message, content})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:send_message, content}, socket) do
    {:noreply, socket} = handle_send_message(content, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:reset_input_flag, socket) do
    {:noreply, assign(socket, :reset_input, false)}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    # Check if message already exists in the list to avoid duplicates
    existing_messages = socket.assigns.messages

    updated_messages =
      if Enum.any?(existing_messages, fn m -> m.id == message.id end) do
        existing_messages
      else
        [message | existing_messages]
      end

    # Remove from typing users if this user was typing
    typing_users =
      Enum.reject(socket.assigns.typing_users, fn user ->
        user.user_id == message.user_id
      end)

    {:noreply, assign(socket, messages: updated_messages, typing_users: typing_users)}
  end

  @impl true
  def handle_info({:user_typing, typing_event}, socket) do
    # Don't show typing indicator for current user
    if typing_event.user_id != socket.assigns.current_user.id do
      # Add user to typing list if not already there
      typing_users =
        if Enum.any?(socket.assigns.typing_users, fn user ->
             user.user_id == typing_event.user_id
           end) do
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
    typing_users =
      Enum.reject(socket.assigns.typing_users, fn user -> user.user_id == user_id end)

    {:noreply, assign(socket, typing_users: typing_users)}
  end

  @impl true
  def handle_info({:notify_typing, _content}, socket) do
    # Broadcast typing status to all users in the conversation
    conversation_id = socket.assigns.conversation.id
    user_id = socket.assigns.current_user.id
    username = socket.assigns.current_user.email

    typing_event = %{
      user_id: user_id,
      username: username,
      is_ai: false
    }

    Phoenix.PubSub.broadcast(
      Peer2peer.PubSub,
      "conversation:#{conversation_id}",
      {:user_typing, typing_event}
    )

    {:noreply, socket}
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
  defp should_trigger_ai_response?(_socket) do
    # Simple implementation: respond if there's at least one AI participant
    # In real implementation this will depend on socket.assigns.ai_participants
    true
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

  # Helper function to get sender name
  defp get_sender_name(message, conversation, ai_participants) do
    cond do
      message.is_ai_generated ->
        # Find AI name
        Enum.find_value(ai_participants, "AI Assistant", fn ai ->
          if ai.id == message.ai_participant_id, do: ai.name
        end)

      true ->
        # Find user name
        Enum.find_value(conversation.participants, "Unknown User", fn participant ->
          if participant.id == message.user_id, do: participant.email
        end)
    end
  end

  defp message_bubble_class(message, current_user) do
    cond do
      message.is_ai_generated ->
        "bg-purple-100 text-gray-800"

      message.user_id == current_user.id ->
        "bg-blue-500 text-white"

      true ->
        "bg-gray-200 text-gray-800"
    end
  end

  defp format_timestamp(datetime) do
    now = DateTime.utc_now()

    cond do
      # Today
      DateTime.to_date(datetime) == DateTime.to_date(now) ->
        Calendar.strftime(datetime, "%H:%M")

      # This year
      datetime.year == now.year ->
        Calendar.strftime(datetime, "%b %d, %H:%M")

      # Different year
      true ->
        Calendar.strftime(datetime, "%b %d, %Y, %H:%M")
    end
  end

  defp format_typing_users(typing_users) do
    case typing_users do
      [] ->
        ""

      [user] ->
        "#{user.username} is typing..."

      [user1, user2] ->
        "#{user1.username} and #{user2.username} are typing..."

      [user1, user2 | _rest] ->
        "#{user1.username}, #{user2.username} and others are typing..."
    end
  end

  # And update the create_message function
  def create_message(%{user: user, conversation: conversation} = params) do
    attrs = Map.take(params, [:content, :message_type, :metadata, :parent_id])

    # Use fully qualified name here
    %Peer2peer.Conversations.Message{}
    # And here
    |> Peer2peer.Conversations.Message.changeset(
      Map.merge(attrs, %{
        conversation_id: conversation.id,
        user_id: user.id,
        is_ai_generated: false
      })
    )
    |> Repo.insert()
  end

  # And the create_ai_message function
  def create_ai_message(%{ai_participant: ai, conversation: conversation} = params) do
    attrs = Map.take(params, [:content, :message_type, :metadata, :parent_id])

    # Use fully qualified name here
    %Peer2peer.Conversations.Message{}
    # And here
    |> Peer2peer.Conversations.Message.changeset(
      Map.merge(attrs, %{
        conversation_id: conversation.id,
        ai_participant_id: ai.id,
        is_ai_generated: true
      })
    )
    |> Repo.insert()
  end
end
