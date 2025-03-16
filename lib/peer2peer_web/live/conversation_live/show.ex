defmodule Peer2peerWeb.ConversationLive.Show do
  use Peer2peerWeb, :live_view

  # Add your existing module imports and aliases here

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # ...existing code...

    socket =
      socket
      |> assign(:page_title, conversation.title)
      |> assign(:conversation, conversation)
      |> assign(:messages, messages)
      |> assign(:ai_participants, ai_participants)
      |> assign(:message_form, to_form(%{"content" => ""}))
      |> assign(:presences, presences)
      |> assign(:typing_users, [])
      # Add this
      |> assign(:reset_input, false)

    {:ok, socket}
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
      |> assign(:reset_input, true)
      |> update(:messages, fn messages -> [message | messages] end)

    # Reset the reset_input flag after a short delay
    Process.send_after(self(), :reset_input_flag, 100)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:reset_input_flag, socket) do
    {:noreply, assign(socket, :reset_input, false)}
  end

  @impl true
  def handle_info(:user_typing, socket) do
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

  # Replace existing handle_event functions with these new handler functions
  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    send(self(), {:send_message, content})
    {:noreply, socket}
  end

  # Add your other handle_event and handle_info functions here

  # Append these helper functions to the ConversationLive.Show module
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

  defp get_username(message, conversation) do
    Enum.find_value(conversation.participants, "Unknown User", fn participant ->
      if participant.id == message.user_id, do: participant.email
    end)
  end

  defp get_ai_name(message, ai_participants) do
    Enum.find_value(ai_participants, "AI Assistant", fn ai ->
      if ai.id == message.ai_participant_id, do: ai.name
    end)
  end

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%H:%M")
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
end
