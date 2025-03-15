defmodule Peer2peerWeb.Presence do
  use Phoenix.Presence,
    otp_app: :peer2peer,
    pubsub_server: Peer2peer.PubSub

  @doc """
  When a user joins a conversation, track their presence
  """
  def track_user_in_conversation(conversation_id, user_id, user_info) do
    track(
      self(),
      "conversation:#{conversation_id}",
      user_id,
      user_info
    )
  end

  @doc """
  List users currently in a conversation
  """
  def list_users_in_conversation(conversation_id) do
    list("conversation:#{conversation_id}")
  end
end
