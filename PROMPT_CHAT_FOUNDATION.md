
Implement the core LiveView chat functionality for the P2P Idea Chat System:
1. LiveView structure for real-time chat
2. PubSub configuration for message broadcasting
3. Presence tracking for active users
4. Basic message sending/receiving functionality
5. Real-time updates with optimistic UI

Provide the necessary module code, templates, and LiveView hooks.

I'll implement the core LiveView chat functionality for your P2P Idea Chat System. This implementation will focus on establishing real-time communication, presence tracking, and a solid foundation for the chat interface.

## 1. First, let's create the AI Integration module

```elixir
# lib/peer2peer/ai/ai.ex
defmodule Peer2peer.AI do
  @moduledoc """
  AI integration module for connecting to external AI services.
  Supports multiple providers and handles API communication.
  """

  require Logger

  # Get configuration
  def config do
    Application.get_env(:peer2peer, __MODULE__, [])
  end

  def default_provider do
    providers = config()[:providers] || [:openai]
    config()[:default_provider] || List.first(providers)
  end

  @doc """
  Generate a response from the AI using the specified provider
  """
  def generate_response(messages, opts \\ []) do
    provider = Keyword.get(opts, :provider, default_provider())
    provider_config = config()[provider] || []

    api_key = get_api_key(provider, provider_config)
    model = Keyword.get(opts, :model) || provider_config[:default_model]

    case provider do
      :openai -> generate_openai_response(messages, api_key, model, opts)
      :anthropic -> generate_anthropic_response(messages, api_key, model, opts)
      _ -> {:error, "Unsupported AI provider: #{provider}"}
    end
  end

  defp get_api_key(provider, provider_config) do
    case provider_config[:api_key] do
      {:system, env_var} -> System.get_env(env_var)
      key when is_binary(key) -> key
      _ -> nil
    end
  end

  defp generate_openai_response(messages, api_key, model, opts) do
    # For now, a simple mock implementation
    # In a real implementation, this would make API calls to OpenAI
    Logger.info("Generating OpenAI response with model: #{model}")

    # Simulate API call delay
    Process.sleep(500)

    {:ok, %{
      content: "This is a simulated response from OpenAI's #{model}.",
      model: model,
      provider: :openai
    }}
  end

  defp generate_anthropic_response(messages, api_key, model, opts) do
    # For now, a simple mock implementation
    # In a real implementation, this would make API calls to Anthropic
    Logger.info("Generating Anthropic response with model: #{model}")

    # Simulate API call delay
    Process.sleep(700)

    {:ok, %{
      content: "This is a simulated response from Anthropic's #{model}.",
      model: model,
      provider: :anthropic
    }}
  end
end
```

## 2. Let's create a ConversationServer for managing conversation state

```elixir
# lib/peer2peer/conversations/conversation_server.ex
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

    {:ok, %{
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
    {:ok, updated_conversation} = Conversations.change_conversation_phase(conversation, next_phase)

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
  defp next_mitosis_phase(:telophase), do: :prophase # Cycle back for now
end
```

## 3. Let's create a supervisor for conversation servers

```elixir
# lib/peer2peer/conversations/conversation_supervisor.ex
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
```

## 4. Update the application.ex file to include new supervisors

```elixir
# lib/peer2peer/application.ex (updated)
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
```

## 5. Now let's create the chat LiveView

```elixir
# lib/peer2peer_web/live/conversation_live/show.ex
defmodule Peer2peerWeb.ConversationLive.Show do
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
```

## 6. Let's create the LiveView template

```heex
<!-- lib/peer2peer_web/live/conversation_live/show.html.heex -->
<div class="flex flex-col h-screen max-h-screen">
  <!-- Conversation header -->
  <div class="flex items-center justify-between p-4 border-b">
    <div>
      <h1 class="text-xl font-semibold"><%= @conversation.title %></h1>
      <p class="text-sm text-gray-500"><%= @conversation.description %></p>
    </div>
    <div class="flex items-center">
      <!-- Mitosis phase indicator -->
      <div class="mr-4">
        <div class="text-xs text-gray-500">Phase</div>
        <div class="flex items-center">
          <span class="font-medium mr-2"><%= String.capitalize(to_string(@conversation.mitosis_phase)) %></span>
          <div class="w-24 h-2 bg-gray-200 rounded-full">
            <div class="h-2 bg-blue-500 rounded-full" style={"width: #{@conversation.phase_progress * 100}%"}></div>
          </div>
        </div>
      </div>

      <!-- Participants indicator -->
      <div class="flex -space-x-2">
        <%= for {_user_id, presence} <- @presences do %>
          <div class="w-8 h-8 rounded-full bg-indigo-500 flex items-center justify-center text-white text-xs border-2 border-white">
            <%= String.first(presence.metas |> List.first() |> Map.get(:username, "?")) %>
          </div>
        <% end %>
      </div>
    </div>
  </div>

  <!-- Chat messages area -->
  <div class="flex-1 overflow-y-auto p-4 space-y-4" id="messages-container" phx-update="prepend">
    <%= for message <- @messages do %>
      <div
        id={"message-#{message.id}"}
        class={"flex #{if message.is_ai_generated, do: 'justify-start', else: if(message.user_id == @current_user.id, do: 'justify-end', else: 'justify-start')}"}
      >
        <div class={"max-w-3/4 rounded-lg p-3 #{message_bubble_class(message, @current_user)}"}>
          <%= if not message.is_ai_generated and message.user_id != @current_user.id do %>
            <div class="font-semibold text-xs mb-1">
              <%= get_username(message, @conversation) %>
            </div>
          <% end %>

          <%= if message.is_ai_generated do %>
            <div class="font-semibold text-xs mb-1 text-purple-700">
              <%= get_ai_name(message, @ai_participants) %> (AI)
            </div>
          <% end %>

          <div class="whitespace-pre-wrap"><%= message.content %></div>
          <div class="text-xs text-gray-400 mt-1 text-right">
            <%= format_timestamp(message.inserted_at) %>
          </div>
        </div>
      </div>
    <% end %>
  </div>

  <!-- Typing indicators -->
  <div class="px-4 h-6">
    <%= if length(@typing_users) > 0 do %>
      <div class="text-sm text-gray-500 italic">
        <%= format_typing_users(@typing_users) %>
      </div>
    <% end %>
  </div>

  <!-- Message input -->
  <div class="border-t p-4">
    <.form for={@message_form} phx-submit="send_message" class="flex">
      <input
        type="text"
        name="content"
        placeholder="Type your message..."
        class="flex-1 rounded-l-lg border border-gray-300 p-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
        autocomplete="off"
        phx-keyup="typing"
        required
      />
      <button
        type="submit"
        class="bg-blue-500 text-white px-4 py-2 rounded-r-lg hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        Send
      </button>
    </.form>
  </div>
</div>
```

## 7. Create helper functions for the conversation LiveView

```elixir
# Add these to lib/peer2peer_web/live/conversation_live/show.ex

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
```

## 8. Update the router to include our conversation LiveView

```elixir
# lib/peer2peer_web/router.ex (update the existing router)

# Add to the authenticated scope:
scope "/", Peer2peerWeb do
  pipe_through [:browser, :require_authenticated_user]

  live_session :require_authenticated_user,
    on_mount: [{Peer2peerWeb.UserAuth, :ensure_authenticated}] do
    live "/users/settings", UserSettingsLive, :edit
    live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email

    # Add conversation routes
    live "/conversations/:id", ConversationLive.Show, :show
  end
end
```

## 9. Let's create a LiveView for listing conversations

```elixir
# lib/peer2peer_web/live/conversation_live/index.ex
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
  def handle_event("create_conversation", %{"title" => title, "description" => description}, socket) do
    case Conversations.create_conversation(%{
      "title" => title,
      "description" => description
    }, socket.assigns.current_user) do
      {:ok, conversation} ->
        # Create default AI participant
        Conversations.create_ai_participant(%{
          "name" => "Assistant",
          "provider" => "openai",
          "model" => "gpt-4-turbo",
          "system_prompt" => "You are a helpful assistant participating in a collaborative conversation.",
          "temperature" => 0.7
        }, conversation)

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
```

## 10. Create the conversation list template

```heex
<!-- lib/peer2peer_web/live/conversation_live/index.html.heex -->
<div class="max-w-4xl mx-auto py-8">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold">Your Conversations</h1>

    <.link
      phx-click={JS.toggle(to: "#new-conversation-form")}
      class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
    >
      New Conversation
    </.link>
  </div>

  <!-- New conversation form -->
  <div id="new-conversation-form" class="mb-8 p-4 bg-gray-100 rounded-lg hidden">
    <h2 class="text-lg font-semibold mb-4">Create a New Conversation</h2>

    <.form for={@new_conversation_form} phx-submit="create_conversation">
      <div class="mb-4">
        <label class="block text-sm font-medium mb-1">Title</label>
        <input
          type="text"
          name="title"
          class="w-full rounded border border-gray-300 p-2"
          placeholder="Conversation title"
          required
        />
      </div>

      <div class="mb-4">
        <label class="block text-sm font-medium mb-1">Description (optional)</label>
        <textarea
          name="description"
          class="w-full rounded border border-gray-300 p-2"
          placeholder="What's this conversation about?"
          rows="3"
        ></textarea>
      </div>

      <div class="flex justify-end">
        <button
          type="button"
          phx-click={JS.hide(to: "#new-conversation-form")}
          class="mr-2 px-4 py-2 text-gray-700 hover:text-gray-900"
        >
          Cancel
        </button>
        <button
          type="submit"
          class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
        >
          Create
        </button>
      </div>
    </.form>
  </div>

  <!-- Conversation list -->
  <div class="space-y-4">
    <%= if Enum.empty?(@conversations) do %>
      <div class="text-center py-12 bg-gray-50 rounded-lg">
        <p class="text-gray-500">You don't have any conversations yet.</p>
        <p class="text-gray-500 mt-2">Click "New Conversation" to start one!</p>
      </div>
    <% else %>
      <%= for conversation <- @conversations do %>
        <.link
          navigate={~p"/conversations/#{conversation.id}"}
          class

continue

Let's continue implementing the LiveView templates and add additional routes to our router:

## 10. Create the conversation list template (continued)

```heex
<!-- lib/peer2peer_web/live/conversation_live/index.html.heex (continued) -->
        <.link
          navigate={~p"/conversations/#{conversation.id}"}
          class="block p-4 border rounded-lg hover:bg-gray-50 transition-colors flex justify-between items-center"
        >
          <div>
            <h3 class="font-medium text-lg"><%= conversation.title %></h3>
            <p class="text-gray-500 text-sm"><%= conversation.description %></p>
            <div class="mt-2 flex items-center text-xs text-gray-400">
              <span class="mr-4">
                Created: <%= Calendar.strftime(conversation.inserted_at, "%b %d, %Y") %>
              </span>
              <span class="flex items-center">
                <span class="inline-block w-2 h-2 rounded-full bg-green-500 mr-1"></span>
                <%= String.capitalize(to_string(conversation.status)) %>
              </span>
              <span class="ml-4">
                Phase: <%= String.capitalize(to_string(conversation.mitosis_phase)) %>
              </span>
            </div>
          </div>
          <div class="text-gray-400">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6">
              <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
            </svg>
          </div>
        </.link>
      <% end %>
    <% end %>
  </div>
</div>
```

## 11. Update the router for the conversation index route

```elixir
# lib/peer2peer_web/router.ex (update the authenticated scope)

scope "/", Peer2peerWeb do
  pipe_through [:browser, :require_authenticated_user]

  live_session :require_authenticated_user,
    on_mount: [{Peer2peerWeb.UserAuth, :ensure_authenticated}] do
    live "/users/settings", UserSettingsLive, :edit
    live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email

    # Add conversation routes
    live "/conversations", ConversationLive.Index, :index
    live "/conversations/:id", ConversationLive.Show, :show
  end
end
```

## 12. Let's modify the home page to redirect logged-in users to conversations

```elixir
# lib/peer2peer_web/controllers/page_controller.ex (modify)
defmodule Peer2peerWeb.PageController do
  use Peer2peerWeb, :controller

  def home(conn, _params) do
    # If user is logged in, redirect to conversations
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/conversations")
    else
      # The home page is often custom made,
      # so skip the default app layout.
      render(conn, :home, layout: false)
    end
  end
end
```

## 13. Let's create a LiveComponent for the Mitosis phase indicator

```elixir
# lib/peer2peer_web/live/components/mitosis_phase_component.ex
defmodule Peer2peerWeb.MitosisPhaseComponent do
  use Peer2peerWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="mitosis-phase-indicator">
      <div class="text-sm font-semibold mb-1">Conversation Phase</div>
      <div class="flex items-center space-x-1">
        <div
          class={"phase-dot #{if phase_active?(:prophase, @phase), do: 'active', else: ''}"}
          phx-click={@show_info && show_modal("prophase-info")}
        >
          <div class="phase-label">Prophase</div>
        </div>
        <div class="phase-line"></div>
        <div
          class={"phase-dot #{if phase_active?(:prometaphase, @phase), do: 'active', else: ''}"}
          phx-click={@show_info && show_modal("prometaphase-info")}
        >
          <div class="phase-label">Prometaphase</div>
        </div>
        <div class="phase-line"></div>
        <div
          class={"phase-dot #{if phase_active?(:metaphase, @phase), do: 'active', else: ''}"}
          phx-click={@show_info && show_modal("metaphase-info")}
        >
          <div class="phase-label">Metaphase</div>
        </div>
        <div class="phase-line"></div>
        <div
          class={"phase-dot #{if phase_active?(:anaphase, @phase), do: 'active', else: ''}"}
          phx-click={@show_info && show_modal("anaphase-info")}
        >
          <div class="phase-label">Anaphase</div>
        </div>
        <div class="phase-line"></div>
        <div
          class={"phase-dot #{if phase_active?(:telophase, @phase), do: 'active', else: ''}"}
          phx-click={@show_info && show_modal("telophase-info")}
        >
          <div class="phase-label">Telophase</div>
        </div>
      </div>

      <div class="mt-2 progress-bar">
        <div class="progress-fill" style={"width: #{@progress * 100}%"}></div>
      </div>

      <div :if={@show_help} class="mt-2 text-xs text-gray-500 italic">
        Click on a phase to learn more about it
      </div>

      <%= if @show_info do %>
        <.modal id="prophase-info">
          <h3 class="text-lg font-semibold mb-2">Prophase</h3>
          <p>Initial ideas are organized and structured. This is where conversations begin and participants start sharing their thoughts.</p>
        </.modal>

        <.modal id="prometaphase-info">
          <h3 class="text-lg font-semibold mb-2">Prometaphase</h3>
          <p>Barriers between topics and users break down. Ideas begin to flow more freely and connections form between different concepts.</p>
        </.modal>

        <.modal id="metaphase-info">
          <h3 class="text-lg font-semibold mb-2">Metaphase</h3>
          <p>Ideas align and reach consensus. The key concepts and points of agreement become clear to all participants.</p>
        </.modal>

        <.modal id="anaphase-info">
          <h3 class="text-lg font-semibold mb-2">Anaphase</h3>
          <p>Conversation begins splitting into separate threads. Distinct topics emerge that may benefit from focused discussion.</p>
        </.modal>

        <.modal id="telophase-info">
          <h3 class="text-lg font-semibold mb-2">Telophase</h3>
          <p>Complete separation into new conversation groups. The original conversation divides into multiple related conversations, each focused on a specific aspect.</p>
        </.modal>
      <% end %>
    </div>
    """
  end

  defp phase_active?(phase, current_phase) do
    # Map phases to their order for comparison
    phase_order = %{
      prophase: 1,
      prometaphase: 2,
      metaphase: 3,
      anaphase: 4,
      telophase: 5
    }

    # A phase is active if it's the current phase or comes before it
    phase_order[phase] <= phase_order[current_phase]
  end
end
```

## 14. Add CSS for the mitosis phase indicator component

```css
/* assets/css/app.css (add this) */

/* Mitosis Phase Indicator */
.mitosis-phase-indicator {
  @apply p-4 border rounded-lg bg-white mb-4;
}

.mitosis-phase-indicator .phase-dot {
  @apply w-5 h-5 rounded-full bg-gray-200 relative cursor-pointer flex items-center justify-center transition-all;
}

.mitosis-phase-indicator .phase-dot.active {
  @apply bg-blue-500;
}

.mitosis-phase-indicator .phase-line {
  @apply flex-1 h-1 bg-gray-200;
}

.mitosis-phase-indicator .phase-line.active {
  @apply bg-blue-500;
}

.mitosis-phase-indicator .phase-label {
  @apply absolute -bottom-6 text-xs transform -translate-x-1/2 left-1/2 whitespace-nowrap hidden;
}

.mitosis-phase-indicator .phase-dot:hover .phase-label {
  @apply block;
}

.mitosis-phase-indicator .progress-bar {
  @apply h-1 bg-gray-100 rounded-full overflow-hidden;
}

.mitosis-phase-indicator .progress-fill {
  @apply h-full bg-blue-500 transition-all duration-500;
}
```

## 15. Update the Show LiveView to use the mitosis phase component

```heex
<!-- lib/peer2peer_web/live/conversation_live/show.html.heex (update the header section) -->

<!-- Conversation header -->
<div class="p-4 border-b">
  <div class="flex items-center justify-between mb-4">
    <div>
      <h1 class="text-xl font-semibold"><%= @conversation.title %></h1>
      <p class="text-sm text-gray-500"><%= @conversation.description %></p>
    </div>

    <!-- Participants indicator -->
    <div class="flex -space-x-2">
      <%= for {_user_id, presence} <- @presences do %>
        <div class="w-8 h-8 rounded-full bg-indigo-500 flex items-center justify-center text-white text-xs border-2 border-white">
          <%= String.first(presence.metas |> List.first() |> Map.get(:username, "?")) %>
        </div>
      <% end %>
    </div>
  </div>

  <!-- Mitosis phase indicator component -->
  <.live_component
    module={Peer2peerWeb.MitosisPhaseComponent}
    id="mitosis-phase"
    phase={@conversation.mitosis_phase}
    progress={@conversation.phase_progress}
    show_info={true}
    show_help={true}
  />
</div>
```

## 16. Add a LiveView for conversation settings and phase control

```elixir
# lib/peer2peer_web/live/conversation_live/settings.ex
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
      |> assign(:conversation_form, to_form(%{
        "title" => conversation.title,
        "description" => conversation.description
      }))
      |> assign(:ai_form, to_form(%{
        "name" => "",
        "provider" => "openai",
        "model" => "gpt-4-turbo",
        "persona" => "",
        "system_prompt" => ""
      }))

    {:ok, socket}
  end

  @impl true
  def handle_event("update_conversation", %{"title" => title, "description" => description}, socket) do
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
          |> assign(:ai_form, to_form(%{
            "name" => "",
            "provider" => "openai",
            "model" => "gpt-4-turbo",
            "persona" => "",
            "system_prompt" => ""
          }))
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
    Peer2peer.Conversations.ConversationSupervisor.ensure_conversation_server(socket.assigns.conversation.id)

    # Send advance phase command to the conversation server
    ConversationServer.advance_phase(socket.assigns.conversation.id)

    {:noreply, put_flash(socket, :info, "Advancing to next phase...")}
  end

  @impl true
  def handle_event("update_progress", %{"progress" => progress_str}, socket) do
    progress = String.to_float(progress_str)

    # Ensure conversation server is running
    Peer2peer.Conversations.ConversationSupervisor.ensure_conversation_server(socket.assigns.conversation.id)

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
          |> assign(:ai_participants, Enum.reject(socket.assigns.ai_participants, &(&1.id == ai_id)))
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
```

## 17. Create the settings view template

```heex
<!-- lib/peer2peer_web/live/conversation_live/settings.html.heex -->
<div class="max-w-4xl mx-auto py-8">
  <.link navigate={~p"/conversations/#{@conversation.id}"} class="flex items-center text-blue-500 mb-4">
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 mr-1">
      <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" />
    </svg>
    Back to conversation
  </.link>

  <h1 class="text-2xl font-bold mb-6">Conversation Settings</h1>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
    <!-- Left column -->
    <div>
      <!-- Basic settings -->
      <div class="bg-white p-6 rounded-lg shadow-sm mb-8">
        <h2 class="text-lg font-semibold mb-4">Basic Information</h2>

        <.form for={@conversation_form} phx-submit="update_conversation">
          <div class="mb-4">
            <label class="block text-sm font-medium mb-1">Title</label>
            <input
              type="text"
              name="title"
              value={@conversation_form.params["title"]}
              class="w-full rounded border border-gray-300 p-2"
              required
            />
          </div>

          <div class="mb-4">
            <label class="block text-sm font-medium mb-1">Description</label>
            <textarea
              name="description"
              class="w-full rounded border border-gray-300 p-2"
              rows="3"
            ><%= @conversation_form.params["description"] %></textarea>
          </div>

          <div class="flex justify-end">
            <button
              type="submit"
              class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
            >
              Update
            </button>
          </div>
        </.form>
      </div>

      <!-- Participants -->
      <div class="bg-white p-6 rounded-lg shadow-sm mb-8">
        <h2 class="text-lg font-semibold mb-4">Participants</h2>

        <div class="mb-4">
          <h3 class="text-sm font-medium mb-2">Current Participants</h3>
          <ul class="divide-y">
            <%= for participant <- @conversation.participants do %>
              <li class="py-2 flex justify-between items-center">
                <span><%= participant.email %></span>
                <span class="text-xs px-2 py-1 bg-gray-100 rounded">
                  <%= if participant.id == @conversation.creator_id, do: "Owner", else: "Member" %>
                </span>
              </li>
            <% end %>
          </ul>
        </div>

        <!-- Add participant feature would go here -->
      </div>
    </div>

    <!-- Right column -->
    <div>
      <!-- Mitosis phase control -->
      <div class="bg-white p-6 rounded-lg shadow-sm mb-8">
        <h2 class="text-lg font-semibold mb-4">Conversation Phase</h2>

        <.live_component
          module={Peer2peerWeb.MitosisPhaseComponent}
          id="settings-mitosis-phase"
          phase={@conversation.mitosis_phase}
          progress={@conversation.phase_progress}
          show_info={true}
          show_help={false}
        />

        <div class="mt-6 space-y-4">
          <div>
            <label class="block text-sm font-medium mb-1">Phase Progress</label>
            <input
              type="range"
              min="0"
              max="1"
              step="0.01"
              value={@conversation.phase_progress}
              phx-change="update_progress"
              name="progress"
              class="w-full"
            />
          </div>

          <div class="flex justify-end">
            <button
              phx-click="advance_phase"
              class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600"
            >
              Advance to Next Phase
            </button>
          </div>
        </div>
      </div>

      <!-- AI participants -->
      <div class="bg-white p-6 rounded-lg shadow-sm">
        <h2 class="text-lg font-semibold mb-4">AI Participants</h2>

        <!-- List current AI participants -->
        <div class="mb-6">
          <h3 class="text-sm font-medium mb-2">Current AI Participants</h3>

          <%= if Enum.empty?(@ai_participants) do %>
            <p class="text-gray-500 text-sm italic">No AI participants added yet.</p>
          <% else %>
            <ul class="divide-y">
              <%= for ai in @ai_participants do %>
                <li class="py-3">
                  <div class="flex justify-between items-start">
                    <div>
                      <div class="font-medium"><%= ai.name %></div>
                      <div class="text-xs text-gray-500">
                        <%= ai.provider %> / <%= ai.model %>
                      </div>
                      <%= if ai.persona && ai.persona != "" do %>
                        <div class="text-sm mt-1"><%= ai.persona %></div>
                      <% end %>
                    </div>
                    <button
                      phx-click="remove_ai"
                      phx-value-id={ai.id}
                      class="text-red-500 hover:text-red-700"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                      </svg>
                    </button>
                  </div>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>

        <!-- Add AI participant form -->
        <div>
          <h3 class="text-sm font-medium mb-2">Add AI Participant</h3>

          <.form for={@ai_form} phx-submit="add_ai_participant">
            <div class="mb-4">
              <label class="block text-sm font-medium mb-1">Name</label>
              <input
                type="text"
                name="name"
                class="w-full rounded border border-gray-300 p-2"
                placeholder="AI Assistant"
                required
              />
            </div>

            <div class="grid grid-cols-2 gap-4 mb-4">
              <div>
                <label class="block text-sm font-medium mb-1">Provider</label>
                <select name="provider" class="w-full rounded border border-gray-300 p-2">
                  <option value="openai">OpenAI</option>
                  <option value="anthropic">Anthropic</option>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium mb-1">Model</label>
                <select name="model" class="w-full rounded border border-gray-300 p-2">
                  <option value="gpt-4-turbo">GPT-4 Turbo</option>
                  <option value="gpt-3.5-turbo">GPT-3.5 Turbo</option>
                  <option value="claude-3-opus">Claude 3 Opus</option>
                  <option value="claude-3-sonnet">Claude 3 Sonnet</option>
                </select>
              </div>
            </div>

            <div class="mb-4">
              <label class="block text-sm font-medium mb-1">Persona (optional)</label>
              <input
                type="text"
                name="persona"
                class="w-full rounded border border-gray-300 p-2"
                placeholder="Helpful, creative assistant"
              />
            </div>

            <div class="mb-4">
              <label class="block text-sm font-medium mb-1">System Prompt (optional)</label>
              <textarea
                name="system_prompt"
                class="w-full rounded border border-gray-300 p-2"
                rows="3"
                placeholder="You are a helpful AI assistant..."
              ></textarea>
            </div>

            <div class="flex justify-end">
              <button
                type="submit"
                class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
              >
                Add AI
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
  </div>
</div>
```

## 18. Update router to include the settings route

```elixir
# lib/peer2peer_web/router.ex (update again)

scope "/", Peer2peerWeb do
  pipe_through [:browser, :require_authenticated_user]

  live_session :require_authenticated_user,
    on_mount: [{Peer2peerWeb.UserAuth, :ensure_authenticated}] do
    live "/users/settings", UserSettingsLive, :edit
    live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email

    # Conversation routes
    live "/conversations", ConversationLive.Index, :index
    live "/conversations/:id", ConversationLive.Show, :show
    live "/conversations/:id/settings", ConversationLive.Settings, :edit
  end
end
```

## 19. Add a settings link to the conversation show page

```heex
<!-- lib/peer2peer_web/live/conversation_live/show.html.heex (add to header) -->

<!-- Update the conversation header -->
<div class="flex items-center justify-between p-4 border-b">
  <div>
    <div class="flex items-center">
      <h1 class="text-xl font-semibold"><%= @conversation.title %></h1>
      <.link navigate={~p"/conversations/#{@conversation.id}/settings"} class="ml-2 text-gray-400 hover:text-gray-600">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
        </svg>
      </.link>
    </div>
    <p class="text-sm text-gray-500"><%= @conversation.description %></p>
  </div>

  <!-- Rest of the header -->
</div>
```

## 20. Let's update the user menu in the root layout

continue

Let's continue implementing our P2P Idea Chat System by updating the user menu and adding more functionality:

## 20. Let's update the user menu in the root layout

```heex
<!-- lib/peer2peer_web/components/layouts/root.html.heex (update the navigation) -->
<!DOCTYPE html>
<html lang="en" class="[scrollbar-gutter:stable]">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <.live_title suffix=" · Peer2Peer">
      <%= assigns[:page_title] || "Home" %>
    </.live_title>
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
    </script>
  </head>
  <body class="bg-gray-50 min-h-screen">
    <header class="bg-white shadow-sm">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex">
            <div class="flex-shrink-0 flex items-center">
              <a href="/" class="text-blue-600 font-bold text-xl">Peer2Peer</a>
            </div>
            <%= if @current_user do %>
              <div class="hidden sm:ml-6 sm:flex sm:space-x-8">
                <.link
                  navigate={~p"/conversations"}
                  class="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
                >
                  Conversations
                </.link>
              </div>
            <% end %>
          </div>

          <div class="flex items-center">
            <%= if @current_user do %>
              <div class="hidden sm:ml-6 sm:flex sm:items-center">
                <!-- User dropdown -->
                <div class="ml-3 relative group">
                  <div>
                    <button type="button" class="flex text-sm rounded-full focus:outline-none" id="user-menu-button">
                      <span class="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white">
                        <%= String.first(@current_user.email) %>
                      </span>
                    </button>
                  </div>
                  <!-- Dropdown menu -->
                  <div class="origin-top-right absolute right-0 mt-2 w-48 rounded-md shadow-lg py-1 bg-white ring-1 ring-black ring-opacity-5 hidden group-hover:block z-10">
                    <div class="px-4 py-2 text-xs text-gray-500">
                      Signed in as
                      <div class="font-medium text-gray-900 truncate"><%= @current_user.email %></div>
                    </div>
                    <div class="border-t border-gray-100"></div>
                    <.link
                      href={~p"/users/settings"}
                      class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    >
                      Settings
                    </.link>
                    <.link
                      href={~p"/users/log_out"}
                      method="delete"
                      class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    >
                      Log out
                    </.link>
                  </div>
                </div>
              </div>

              <!-- Mobile menu button -->
              <div class="sm:hidden flex items-center">
                <button type="button" class="mobile-menu-button inline-flex items-center justify-center p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-blue-500">
                  <svg class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
                  </svg>
                </button>
              </div>
            <% else %>
              <div class="hidden sm:flex sm:items-center sm:ml-6">
                <.link
                  href={~p"/users/register"}
                  class="text-gray-500 hover:text-gray-700 px-3 py-2 rounded-md text-sm font-medium"
                >
                  Register
                </.link>
                <.link
                  href={~p"/users/log_in"}
                  class="ml-2 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700"
                >
                  Log in
                </.link>
              </div>

              <!-- Mobile menu button for anonymous users -->
              <div class="sm:hidden flex items-center">
                <button type="button" class="mobile-menu-button inline-flex items-center justify-center p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-blue-500">
                  <svg class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
                  </svg>
                </button>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Mobile menu, show/hide based on menu state. -->
      <div class="sm:hidden hidden" id="mobile-menu">
        <div class="pt-2 pb-3 space-y-1">
          <%= if @current_user do %>
            <.link
              navigate={~p"/conversations"}
              class="text-gray-500 hover:text-gray-700 block px-3 py-2 rounded-md text-base font-medium"
            >
              Conversations
            </.link>
            <.link
              href={~p"/users/settings"}
              class="text-gray-500 hover:text-gray-700 block px-3 py-2 rounded-md text-base font-medium"
            >
              Settings
            </.link>
            <.link
              href={~p"/users/log_out"}
              method="delete"
              class="text-gray-500 hover:text-gray-700 block px-3 py-2 rounded-md text-base font-medium"
            >
              Log out
            </.link>
          <% else %>
            <.link
              href={~p"/users/register"}
              class="text-gray-500 hover:text-gray-700 block px-3 py-2 rounded-md text-base font-medium"
            >
              Register
            </.link>
            <.link
              href={~p"/users/log_in"}
              class="text-gray-500 hover:text-gray-700 block px-3 py-2 rounded-md text-base font-medium"
            >
              Log in
            </.link>
          <% end %>
        </div>
      </div>
    </header>

    <main>
      {@inner_content}
    </main>
  </body>
</html>
```

## 21. Add JavaScript for mobile menu toggle

```javascript
// assets/js/app.js (add this)

// Mobile menu toggle
document.addEventListener("DOMContentLoaded", () => {
  const mobileMenuButton = document.querySelector(".mobile-menu-button");
  const mobileMenu = document.getElementById("mobile-menu");

  if (mobileMenuButton && mobileMenu) {
    mobileMenuButton.addEventListener("click", () => {
      mobileMenu.classList.toggle("hidden");
    });
  }
});
```

## 22. Create a message component for better message rendering

```elixir
# lib/peer2peer_web/live/components/message_component.ex
defmodule Peer2peerWeb.MessageComponent do
  use Peer2peerWeb, :live_component

  def render(assigns) do
    ~H"""
    <div
      id={"message-#{@message.id}"}
      class={"flex #{message_alignment(@message, @current_user)}"}
    >
      <div class={"max-w-3/4 rounded-lg p-3 #{message_bubble_class(@message, @current_user)}"}>
        <%= if show_sender?(@message, @current_user) do %>
          <div class="font-semibold text-xs mb-1 flex items-center">
            <%= if @message.is_ai_generated do %>
              <span class="text-purple-700 flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-3 h-3 mr-1">
                  <path d="M16.5 7.5h-9v9h9v-9z" />
                  <path fill-rule="evenodd" d="M8.25 2.25A.75.75 0 019 3v.75h2.25V3a.75.75 0 011.5 0v.75H15V3a.75.75 0 011.5 0v.75h.75a3 3 0 013 3v.75H21A.75.75 0 0121 9h-.75v2.25H21a.75.75 0 010 1.5h-.75V15H21a.75.75 0 010 1.5h-.75v.75a3 3 0 01-3 3h-.75V21a.75.75 0 01-1.5 0v-.75h-2.25V21a.75.75 0 01-1.5 0v-.75H9V21a.75.75 0 01-1.5 0v-.75h-.75a3 3 0 01-3-3v-.75H3A.75.75 0 013 15h.75v-2.25H3a.75.75 0 010-1.5h.75V9H3a.75.75 0 010-1.5h.75v-.75a3 3 0 013-3h.75V3a.75.75 0 01.75-.75zM6 6.75A.75.75 0 016.75 6h10.5a.75.75 0 01.75.75v10.5a.75.75 0 01-.75.75H6.75a.75.75 0 01-.75-.75V6.75z" clip-rule="evenodd" />
                </svg>
                <%= @sender_name %> (AI)
              </span>
            <% else %>
              <%= @sender_name %>
            <% end %>
          </div>
        <% end %>

        <div class="whitespace-pre-wrap break-words"><%= @message.content %></div>

        <div class="text-xs text-gray-400 mt-1 text-right flex justify-end items-center">
          <%= format_timestamp(@message.inserted_at) %>
          <%= if @message.user_id == @current_user.id do %>
            <span class="ml-1">
              <%= if @message.status == :read do %>
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-3 h-3">
                  <path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clip-rule="evenodd" />
                </svg>
              <% else %>
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-3 h-3">
                  <path d="M9.375 3a1.875 1.875 0 000 3.75h1.875v4.5H3.375A1.875 1.875 0 011.5 9.375v-.75c0-1.036.84-1.875 1.875-1.875h3.193A3.375 3.375 0 0112 2.753a3.375 3.375 0 015.432 3.997h3.943c1.035 0 1.875.84 1.875 1.875v.75c0 1.036-.84 1.875-1.875 1.875H18.75v4.5h-1.875a1.875 1.875 0 10-1.875 1.875h1.875V18.75h-1.875a1.875 1.875 0 103.75 0v-1.875c1.036 0 1.875-.84 1.875-1.875v-.75A1.875 1.875 0 0018.75 12.5h-3.75v-4.5h3.75a1.875 1.875 0 001.875-1.875v-.75c0-1.036-.84-1.875-1.875-1.875h-3.943A3.375 3.375 0 0012 7.373a3.375 3.375 0 00-5.432-3.997H3.375a1.875 1.875 0 00-1.875 1.875v.75c0 1.036.84 1.875 1.875 1.875H6.75v4.5H3.375a1.875 1.875 0 00-1.875 1.875v.75c0 1.036.84 1.875 1.875 1.875H4.5v1.875c0 1.035.84 1.875 1.875 1.875h.75a1.875 1.875 0 001.875-1.875V16.5h7.5v1.875c0 1.035.84 1.875 1.875 1.875h.75a1.875 1.875 0 001.875-1.875V16.5h1.875A1.875 1.875 0 0018.75 14.625v-.75a1.875 1.875 0 00-1.875-1.875H15v-4.5h1.875A1.875 1.875 0 0018.75 5.625v-.75A1.875 1.875 0 0016.875 3H15.75a3.375 3.375 0 00-6.375 0zM7.5 12h6v1.5h-6V12zm-3-6.75A.75.75 0 015.25 6h.75a.75.75 0 01.75.75v.75H4.5v-.75zm0 6A.75.75 0 015.25 12h.75a.75.75 0 01.75.75v.75H4.5v-.75zM15 5.25a.75.75 0 00-.75.75v.75h1.5V6a.75.75 0 00-.75-.75zm0 6a.75.75 0 00-.75.75v.75h1.5v-.75a.75.75 0 00-.75-.75z" />
                </svg>
              <% end %>
            </span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp message_alignment(message, current_user) do
    cond do
      message.is_ai_generated ->
        "justify-start"

      message.user_id == current_user.id ->
        "justify-end"

      true ->
        "justify-start"
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

  defp show_sender?(message, current_user) do
    message.is_ai_generated || message.user_id != current_user.id
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
end
```

## 23. Update the conversation show template to use the message component

```heex
<!-- lib/peer2peer_web/live/conversation_live/show.html.heex (update the messages section) -->

<!-- Chat messages area -->
<div class="flex-1 overflow-y-auto p-4 space-y-4" id="messages-container" phx-update="prepend">
  <%= for message <- @messages do %>
    <.live_component
      module={Peer2peerWeb.MessageComponent}
      id={"message-#{message.id}"}
      message={message}
      current_user={@current_user}
      sender_name={get_sender_name(message, @conversation, @ai_participants)}
    />
  <% end %>
</div>
```

## 24. Add the helper function to the Show LiveView

```elixir
# lib/peer2peer_web/live/conversation_live/show.ex (add this helper)

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
```

## 25. Let's create a live component for typing indicators

```elixir
# lib/peer2peer_web/live/components/typing_indicator_component.ex
defmodule Peer2peerWeb.TypingIndicatorComponent do
  use Peer2peerWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex items-center text-gray-500 text-sm p-1 animate-pulse">
      <div class={"#{if @is_ai, do: 'text-purple-600', else: 'text-gray-600'} font-medium mr-2"}>
        <%= @username %>
      </div>
      <div class="flex items-center">
        <div class="typing-dot"></div>
        <div class="typing-dot animation-delay-200"></div>
        <div class="typing-dot animation-delay-400"></div>
      </div>
    </div>
    """
  end
end
```

## 26. Add CSS for typing indicators

```css
/* assets/css/app.css (add this) */

/* Typing indicator */
.typing-dot {
  @apply bg-current h-1.5 w-1.5 rounded-full mx-0.5 animate-bounce;
}

.animation-delay-200 {
  animation-delay: 0.2s;
}

.animation-delay-400 {
  animation-delay: 0.4s;
}
```

## 27. Update the conversation show template to use the typing indicator component

```heex
<!-- lib/peer2peer_web/live/conversation_live/show.html.heex (update the typing indicators) -->

<!-- Typing indicators -->
<div class="px-4 h-12 flex flex-col justify-center">
  <%= if length(@typing_users) > 0 do %>
    <div class="flex flex-col space-y-1">
      <%= for user <- @typing_users do %>
        <.live_component
          module={Peer2peerWeb.TypingIndicatorComponent}
          id={"typing-#{user.user_id}"}
          username={user.username}
          is_ai={Map.get(user, :is_ai, false)}
        />
      <% end %>
    </div>
  <% end %>
</div>
```

## 28. Let's add a message input component with better UX

```elixir
# lib/peer2peer_web/live/components/message_input_component.ex
defmodule Peer2peerWeb.MessageInputComponent do
  use Peer2peerWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="border-t p-3">
      <.form for={@form} phx-submit="send_message" phx-target={@myself} class="relative">
        <textarea
          id="message-input"
          name="content"
          placeholder="Type your message..."
          class="w-full rounded-lg border border-gray-300 pr-16 py-2 px-3 resize-none focus:outline-none focus:ring-2 focus:ring-blue-500"
          style="min-height: 60px; max-height: 200px"
          phx-keydown={handle_keydown()}
          phx-keyup="typing"
          phx-target={@myself}
          phx-update="ignore"
          autocomplete="off"
          required
        ><%= @form.params["content"] %></textarea>
        <button
          type="submit"
          class="absolute right-2 bottom-2 bg-blue-500 text-white rounded-lg p-2 hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5" />
          </svg>
        </button>
      </.form>
    </div>
    """
  end

  def handle_keydown(js \\ %JS{}) do
    js
    |> JS.push("handle_keydown")
    |> JS.dispatch("input", to: "textarea")
  end

  def update(%{reset: true} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:form, to_form(%{"content" => ""}))

    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def handle_event("handle_keydown", %{"key" => "Enter", "shiftKey" => false}, socket) do
    # Submit form on Enter without Shift
    send(self(), :submit_message)
    {:noreply, socket}
  end

  def handle_event("handle_keydown", _params, socket) do
    # Handle other keydown events
    {:noreply, socket}
  end

  def handle_event("typing", _params, socket) do
    # Notify parent that user is typing
    send(self(), :user_typing)
    {:noreply, socket}
  end

  def handle_event("send_message", %{"content" => content}, socket) do
    if String.trim(content) != "" do
      send(self(), {:send_message, content})
    end

    {:noreply, socket}
  end
end
```

## 29. Update the conversation show template to use the message input component

```heex
<!-- lib/peer2peer_web/live/conversation_live/show.html.heex (update the input section) -->

<!-- Message input -->
<.live_component
  module={Peer2peerWeb.MessageInputComponent}
  id="message-input"
  form={@message_form}
  reset={@reset_input}
/>
```

## 30. Update the Show LiveView to handle the new message input component

```elixir
# lib/peer2peer_web/live/conversation_live/show.ex (update)

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
    |> assign(:reset_input, false)  # Add this

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
```

## 31. Add a scroll-to-bottom feature for the chat

```javascript
// assets/js/app.js (add this)

// Chat scrolling functionality
document.addEventListener("DOMContentLoaded", () => {
  const messagesContainer = document.getElementById("messages-container");

  if (messagesContainer) {
    const scrollToBottom = () => {
      messagesContainer.scrollTop = messagesContainer.scrollHeight;
    };

    // Scroll to bottom on initial load
    scrollToBottom();

    // Create a mutation observer to watch for new messages
    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.addedNodes.length) {
          scrollToBottom();
        }
      }
    });

    // Start observing the messages container
    observer.observe(messagesContainer, { childList: true });
  }
});
```
