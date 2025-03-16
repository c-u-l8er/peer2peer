defmodule Peer2peer.Conversations.ConversationRelationship do
  use Ecto.Schema
  import Ecto.Changeset

  alias Peer2peer.Conversations.Conversation

  schema "conversation_relationships" do
    field :relationship_type, Ecto.Enum,
      values: [:division, :reference, :continuation],
      default: :division

    # Store details about relationship (division points, topics, etc.)
    field :metadata, :map, default: %{}

    # Bidirectional relationship
    belongs_to :parent, Conversation
    belongs_to :child, Conversation

    timestamps(type: :utc_datetime)
  end

  @required_fields [:relationship_type, :parent_id, :child_id]
  @optional_fields [:metadata]

  def changeset(relationship, attrs) do
    relationship
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:parent_id)
    |> foreign_key_constraint(:child_id)
    |> unique_constraint([:parent_id, :child_id])
    |> check_constraint(:id,
      name: :no_self_relationships,
      message: "A conversation cannot have a relationship with itself"
    )
  end
end
