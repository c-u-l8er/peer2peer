defmodule Peer2peer.Conversations.Message do
  use Ecto.Schema
  import Ecto.Changeset

  alias Peer2peer.Accounts.User
  alias Peer2peer.Conversations.{Conversation, AIParticipant}

  schema "messages" do
    field :content, :string
    field :message_type, Ecto.Enum, values: [:text, :system, :image, :file, :code], default: :text
    field :status, Ecto.Enum, values: [:sent, :delivered, :read, :error], default: :sent
    field :metadata, :map, default: %{}
    # Used for highlighting key messages
    field :importance, :integer, default: 0
    field :is_ai_generated, :boolean, default: false

    # Relationships
    belongs_to :conversation, Conversation
    belongs_to :user, User
    belongs_to :ai_participant, AIParticipant

    # For threading/replying
    belongs_to :parent_message, Peer2peer.Conversations.Message, foreign_key: :parent_id
    has_many :replies, Peer2peer.Conversations.Message, foreign_key: :parent_id

    timestamps(type: :utc_datetime)
  end

  @required_fields [:content, :conversation_id]
  @optional_fields [
    :message_type,
    :status,
    :metadata,
    :importance,
    :is_ai_generated,
    :user_id,
    :ai_participant_id,
    :parent_id
  ]

  def changeset(message, attrs) do
    message
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_sender_presence()
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:ai_participant_id)
    |> foreign_key_constraint(:parent_id)
  end

  # Either user_id or ai_participant_id must be present
  defp validate_sender_presence(changeset) do
    user_id = get_field(changeset, :user_id)
    ai_participant_id = get_field(changeset, :ai_participant_id)

    if is_nil(user_id) and is_nil(ai_participant_id) do
      add_error(changeset, :sender, "either user_id or ai_participant_id must be present")
    else
      changeset
    end
  end
end
