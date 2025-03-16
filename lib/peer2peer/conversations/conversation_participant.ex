defmodule Peer2peer.Conversations.ConversationParticipant do
  use Ecto.Schema
  import Ecto.Changeset

  alias Peer2peer.Accounts.User
  alias Peer2peer.Conversations.Conversation

  schema "conversation_participants" do
    field :role, Ecto.Enum, values: [:owner, :member, :observer], default: :member
    field :joined_at, :utc_datetime
    field :last_read_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :user, User
    belongs_to :conversation, Conversation

    timestamps(type: :utc_datetime)
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:role, :joined_at, :last_read_at, :metadata, :user_id, :conversation_id])
    |> validate_required([:role, :user_id, :conversation_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:conversation_id)
    |> unique_constraint([:user_id, :conversation_id],
      name: :conversation_participants_user_id_conversation_id_index
    )
  end
end
