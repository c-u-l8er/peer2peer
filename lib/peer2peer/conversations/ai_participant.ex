defmodule Peer2peer.Conversations.AIParticipant do
  use Ecto.Schema
  import Ecto.Changeset

  alias Peer2peer.Conversations.{Conversation, Message}

  schema "ai_participants" do
    field :name, :string
    field :provider, Ecto.Enum, values: [:openai, :anthropic, :local], default: :openai
    field :model, :string
    # Description of AI's personality/role
    field :persona, :string
    # System instructions for the AI
    field :system_prompt, :string
    field :temperature, :float, default: 0.7
    field :max_tokens, :integer
    field :metadata, :map, default: %{}
    field :active, :boolean, default: true

    # Relationships
    belongs_to :conversation, Conversation
    has_many :messages, Message

    timestamps(type: :utc_datetime)
  end

  @required_fields [:name, :provider, :model, :conversation_id]
  @optional_fields [:persona, :system_prompt, :temperature, :max_tokens, :metadata, :active]

  def changeset(ai_participant, attrs) do
    ai_participant
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:temperature, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 2.0)
    |> foreign_key_constraint(:conversation_id)
  end
end
