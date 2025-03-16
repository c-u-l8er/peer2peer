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
