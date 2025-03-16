defmodule Peer2peerWeb.ConversationLive.Index do
  use Peer2peerWeb, :live_view

  alias Peer2peer.Conversations
  alias Peer2peer.Conversations.Conversation

  @impl true
  def mount(_params, _session, socket) do
    conversations = Conversations.list_conversations(socket.assigns.current_user)

    socket =
      socket
      |> assign(:page_title, "Conversations")
      |> assign(:conversations, conversations)
      |> assign(:new_conversation_form, to_form(%{"title" => "", "description" => ""}))

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "create_conversation",
        %{"title" => title, "description" => description},
        socket
      ) do
    case Conversations.create_conversation(
           %{
             "title" => title,
             "description" => description
           },
           socket.assigns.current_user
         ) do
      {:ok, conversation} ->
        # Create default AI participant
        Conversations.create_ai_participant(
          %{
            "name" => "Assistant",
            "provider" => "openai",
            "model" => "gpt-4-turbo",
            "system_prompt" =>
              "You are a helpful assistant participating in a collaborative conversation.",
            "temperature" => 0.7
          },
          conversation
        )

        socket =
          socket
          |> put_flash(:info, "Conversation created successfully.")
          |> push_navigate(to: ~p"/conversations/#{conversation.id}")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(:error, "Error creating conversation.")
          |> assign(:new_conversation_form, to_form(changeset))

        {:noreply, socket}
    end
  end
end
