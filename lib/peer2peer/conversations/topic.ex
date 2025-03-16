defmodule Peer2peer.Conversations.Topic do
  use Ecto.Schema
  import Ecto.Changeset

  alias Peer2peer.Conversations.ConversationTopic

  schema "topics" do
    field :name, :string
    field :description, :string
    field :metadata, :map, default: %{}

    # Many-to-many relationship with conversations
    has_many :conversation_topics, ConversationTopic
    has_many :conversations, through: [:conversation_topics, :conversation]

    timestamps(type: :utc_datetime)
  end

  @required_fields [:name]
  @optional_fields [:description, :metadata]

  def changeset(topic, attrs) do
    topic
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:name)
  end
end
