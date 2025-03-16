defmodule Peer2peer.Conversations.ConversationTopic do
  use Ecto.Schema
  import Ecto.Changeset

  alias Peer2peer.Conversations.{Conversation, Topic}

  schema "conversation_topics" do
    # Strength of topic in conversation (0.0 to 1.0)
    field :relevance, :float, default: 1.0
    field :detected_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :conversation, Conversation
    belongs_to :topic, Topic

    timestamps(type: :utc_datetime)
  end

  @required_fields [:conversation_id, :topic_id]
  @optional_fields [:relevance, :detected_at, :metadata]

  def changeset(conversation_topic, attrs) do
    conversation_topic
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:relevance, greater_than: 0.0, less_than_or_equal_to: 1.0)
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:topic_id)
    |> unique_constraint([:conversation_id, :topic_id])
  end
end
