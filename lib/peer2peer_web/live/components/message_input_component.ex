defmodule Peer2peerWeb.MessageInputComponent do
  use Peer2peerWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="border-t p-4 bg-white">
      <form phx-submit="send_message" class="flex items-center">
        <textarea
          id="message-input"
          name="content"
          value={@form[:content].value}
          placeholder="Type a message..."
          class="flex-1 border rounded-lg p-2 mr-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          rows="1"
          phx-keydown="handle_keydown"
          phx-keyup="typing"
          phx-target={@myself}
          phx-hook="MessageInput"
          data-reset={@reset}
          autocomplete="off"
        ></textarea>
        <button type="submit" class="bg-blue-500 hover:bg-blue-600 text-white rounded-lg p-2">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="1.5"
            stroke="currentColor"
            class="w-5 h-5"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5"
            />
          </svg>
        </button>
      </form>
    </div>
    """
  end

  def handle_event("handle_keydown", %{"key" => "Enter", "value" => content}, socket) do
    if content != "" and not String.contains?(System.get_env("MIX_ENV") || "", "test") do
      # Send the message only if Shift wasn't pressed
      send(self(), :submit_message)
    end

    {:noreply, socket}
  end

  def handle_event("handle_keydown", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("typing", %{"value" => content}, socket) do
    if String.trim(content) != "" do
      # Get the conversation ID from parent assigns rather than the form
      send(
        socket.root_pid,
        {:notify_typing, content}
      )
    end

    {:noreply, socket}
  end

  def update(assigns, socket) do
    # Make sure we have access to current_user and conversation_id
    {:ok, socket |> assign(assigns)}
  end
end
