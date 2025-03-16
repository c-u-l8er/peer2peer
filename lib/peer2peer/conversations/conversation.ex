defmodule Peer2peer.Conversations.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Peer2peer.Accounts.User
  alias Peer2peer.Conversations.{Message, ConversationRelationship, AIParticipant}

  schema "conversations" do
    field :title, :string
    field :description, :string
    field :status, Ecto.Enum, values: [:active, :archived, :divided], default: :active

    field :mitosis_phase, Ecto.Enum,
      values: [:prophase, :prometaphase, :metaphase, :anaphase, :telophase],
      default: :prophase

    # Progress within the current phase (0.0 to 1.0)
    field :phase_progress, :float, default: 0.0
    field :metadata, :map, default: %{}

    # Relationships
    belongs_to :creator, User

    many_to_many :participants, User,
      join_through: "conversation_participants",
      on_replace: :delete

    has_many :messages, Message
    has_many :ai_participants, AIParticipant

    # Parent/child relationships
    has_many :child_relationships, ConversationRelationship, foreign_key: :parent_id
    has_many :children, through: [:child_relationships, :child]
    has_many :parent_relationships, ConversationRelationship, foreign_key: :child_id
    has_many :parents, through: [:parent_relationships, :parent]

    timestamps(type: :utc_datetime)
  end

  @required_fields [:title, :creator_id]
  @optional_fields [:description, :status, :mitosis_phase, :phase_progress, :metadata]

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:phase_progress, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> foreign_key_constraint(:creator_id)
  end

  def phase_transition_changeset(conversation, new_phase) do
    conversation
    |> change(mitosis_phase: new_phase, phase_progress: 0.0)
  end

  def update_progress_changeset(conversation, progress) do
    conversation
    |> change(phase_progress: progress)
  end
end
