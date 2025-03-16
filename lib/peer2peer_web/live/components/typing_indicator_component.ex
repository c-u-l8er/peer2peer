defmodule Peer2peerWeb.TypingIndicatorComponent do
  use Peer2peerWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex items-center text-gray-500 text-sm p-1 animate-pulse">
      <div class={"#{if @is_ai, do: 'text-purple-600', else: 'text-gray-600'} font-medium mr-2"}>
        {@username}
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
