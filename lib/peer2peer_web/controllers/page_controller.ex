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
