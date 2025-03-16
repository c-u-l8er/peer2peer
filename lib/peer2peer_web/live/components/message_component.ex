defmodule Peer2peerWeb.MessageComponent do
  use Peer2peerWeb, :live_component

  def render(assigns) do
    ~H"""
    <div id={"message-#{@message.id}"} class={"flex #{message_alignment(@message, @current_user)}"}>
      <div class={"max-w-3/4 rounded-lg p-3 #{message_bubble_class(@message, @current_user)}"}>
        <%= if show_sender?(@message, @current_user) do %>
          <div class="font-semibold text-xs mb-1 flex items-center">
            <%= if @message.is_ai_generated do %>
              <span class="text-purple-700 flex items-center">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                  class="w-3 h-3 mr-1"
                >
                  <path d="M16.5 7.5h-9v9h9v-9z" />
                  <path
                    fill-rule="evenodd"
                    d="M8.25 2.25A.75.75 0 019 3v.75h2.25V3a.75.75 0 011.5 0v.75H15V3a.75.75 0 011.5 0v.75h.75a3 3 0 013 3v.75H21A.75.75 0 0121 9h-.75v2.25H21a.75.75 0 010 1.5h-.75V15H21a.75.75 0 010 1.5h-.75v.75a3 3 0 01-3 3h-.75V21a.75.75 0 01-1.5 0v-.75h-2.25V21a.75.75 0 01-1.5 0v-.75H9V21a.75.75 0 01-1.5 0v-.75h-.75a3 3 0 01-3-3v-.75H3A.75.75 0 013 15h.75v-2.25H3a.75.75 0 010-1.5h.75V9H3a.75.75 0 010-1.5h.75v-.75a3 3 0 013-3h.75V3a.75.75 0 01.75-.75zM6 6.75A.75.75 0 016.75 6h10.5a.75.75 0 01.75.75v10.5a.75.75 0 01-.75.75H6.75a.75.75 0 01-.75-.75V6.75z"
                    clip-rule="evenodd"
                  />
                </svg>
                {@sender_name} (AI)
              </span>
            <% else %>
              {@sender_name}
            <% end %>
          </div>
        <% end %>

        <div class="whitespace-pre-wrap break-words">{@message.content}</div>

        <div class="text-xs text-gray-400 mt-1 text-right flex justify-end items-center">
          {format_timestamp(@message.inserted_at)}
          <%= if @message.user_id == @current_user.id do %>
            <span class="ml-1">
              <%= if @message.status == :read do %>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  class="w-3 h-3"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
              <% else %>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  class="w-3 h-3"
                >
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
