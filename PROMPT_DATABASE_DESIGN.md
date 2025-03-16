
Design the database schemas for the P2P Idea Chat System, including:
1. User schema (with authentication)
2. Conversation schema (supporting the mitosis concept)
3. Message schema (supporting both human and AI messages)
4. ConversationRelationship schema (for tracking parent/child relationships)
5. AIParticipant schema (for configuring AI in conversations)

Include all necessary fields, associations, and migrations.

Looking at your files, I see you already have a Phoenix project set up with authentication using Phx.Gen.Auth. Now you need to design the database schemas for the P2P Idea Chat System as requested.

I'll create comprehensive schemas following your requirements, with proper associations and migrations. These schemas will support your mitosis-based conversation evolution concept.

Let's start by designing the required schemas:

## 1. First, let's create the Conversation schema

```elixir
# lib/peer2peer/conversations/conversation.ex
defmodule Peer2peer.Conversations.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Peer2peer.Accounts.User
  alias Peer2peer.Conversations.{Message, ConversationRelationship, AIParticipant}

  schema "conversations" do
    field :title, :string
    field :description, :string
    field :status, Ecto.Enum, values: [:active, :archived, :divided], default: :active
    field :mitosis_phase, Ecto.Enum, values: [:prophase, :prometaphase, :metaphase, :anaphase, :telophase], default: :prophase
    field :phase_progress, :float, default: 0.0  # Progress within the current phase (0.0 to 1.0)
    field :metadata, :map, default: %{}

    # Relationships
    belongs_to :creator, User
    many_to_many :participants, User, join_through: "conversation_participants", on_replace: :delete
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
```

## 2. Now let's create the ConversationParticipant schema (join table)

```elixir
# lib/peer2peer/conversations/conversation_participant.ex
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
    |> unique_constraint([:user_id, :conversation_id], name: :conversation_participants_user_id_conversation_id_index)
  end
end
```

## 3. Let's create the Message schema

```elixir
# lib/peer2peer/conversations/message.ex
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
    field :importance, :integer, default: 0  # Used for highlighting key messages
    field :is_ai_generated, :boolean, default: false

    # Relationships
    belongs_to :conversation, Conversation
    belongs_to :user, User
    belongs_to :ai_participant, AIParticipant

    # For threading/replying
    belongs_to :parent_message, Message, foreign_key: :parent_id
    has_many :replies, Message, foreign_key: :parent_id

    timestamps(type: :utc_datetime)
  end

  @required_fields [:content, :conversation_id]
  @optional_fields [:message_type, :status, :metadata, :importance, :is_ai_generated,
                   :user_id, :ai_participant_id, :parent_id]

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
```

## 4. Let's create the ConversationRelationship schema

```elixir
# lib/peer2peer/conversations/conversation_relationship.ex
defmodule Peer2peer.Conversations.ConversationRelationship do
  use Ecto.Schema
  import Ecto.Changeset

  alias Peer2peer.Conversations.Conversation

  schema "conversation_relationships" do
    field :relationship_type, Ecto.Enum, values: [:division, :reference, :continuation], default: :division
    field :metadata, :map, default: %{}  # Store details about relationship (division points, topics, etc.)

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
    |> check_constraint(:id, name: :no_self_relationships, message: "A conversation cannot have a relationship with itself")
  end
end
```

## 5. Let's create the AIParticipant schema

```elixir
# lib/peer2peer/conversations/ai_participant.ex
defmodule Peer2peer.Conversations.AIParticipant do
  use Ecto.Schema
  import Ecto.Changeset

  alias Peer2peer.Conversations.{Conversation, Message}

  schema "ai_participants" do
    field :name, :string
    field :provider, Ecto.Enum, values: [:openai, :anthropic, :local], default: :openai
    field :model, :string
    field :persona, :string  # Description of AI's personality/role
    field :system_prompt, :string  # System instructions for the AI
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
```

## 6. Let's create the Topic and ConversationTopic schemas for tracking conversation topics

```elixir
# lib/peer2peer/conversations/topic.ex
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
```

```elixir
# lib/peer2peer/conversations/conversation_topic.ex
defmodule Peer2peer.Conversations.ConversationTopic do
  use Ecto.Schema
  import Ecto.Changeset

  alias Peer2peer.Conversations.{Conversation, Topic}

  schema "conversation_topics" do
    field :relevance, :float, default: 1.0  # Strength of topic in conversation (0.0 to 1.0)
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
```

## Now, let's create the migration files:

### 1. Create the conversations table:

```elixir
# priv/repo/migrations/TIMESTAMP_create_conversations.exs
defmodule Peer2peer.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :title, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "active"
      add :mitosis_phase, :string, null: false, default: "prophase"
      add :phase_progress, :float, null: false, default: 0.0
      add :metadata, :map, default: %{}
      add :creator_id, references(:users, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:conversations, [:creator_id])
    create index(:conversations, [:status])
    create index(:conversations, [:mitosis_phase])
  end
end
```

### 2. Create the conversation_participants table:

```elixir
# priv/repo/migrations/TIMESTAMP_create_conversation_participants.exs
defmodule Peer2peer.Repo.Migrations.CreateConversationParticipants do
  use Ecto.Migration

  def change do
    create table(:conversation_participants) do
      add :role, :string, null: false, default: "member"
      add :joined_at, :utc_datetime, default: fragment("NOW()")
      add :last_read_at, :utc_datetime
      add :metadata, :map, default: %{}
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:conversation_participants, [:user_id])
    create index(:conversation_participants, [:conversation_id])
    create unique_index(:conversation_participants, [:user_id, :conversation_id])
  end
end
```

### 3. Create the messages table:

```elixir
# priv/repo/migrations/TIMESTAMP_create_messages.exs
defmodule Peer2peer.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :content, :text, null: false
      add :message_type, :string, null: false, default: "text"
      add :status, :string, null: false, default: "sent"
      add :metadata, :map, default: %{}
      add :importance, :integer, default: 0
      add :is_ai_generated, :boolean, default: false
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)
      add :ai_participant_id, references(:ai_participants, on_delete: :nilify_all)
      add :parent_id, references(:messages, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:conversation_id])
    create index(:messages, [:user_id])
    create index(:messages, [:ai_participant_id])
    create index(:messages, [:parent_id])
    create constraint("messages", "sender_must_exist",
      check: "(user_id IS NOT NULL) OR (ai_participant_id IS NOT NULL)")
  end
end
```

### 4. Create the ai_participants table:

```elixir
# priv/repo/migrations/TIMESTAMP_create_ai_participants.exs
defmodule Peer2peer.Repo.Migrations.CreateAIParticipants do
  use Ecto.Migration

  def change do
    create table(:ai_participants) do
      add :name, :string, null: false
      add :provider, :string, null: false
      add :model, :string, null: false
      add :persona, :text
      add :system_prompt, :text
      add :temperature, :float, default: 0.7
      add :max_tokens, :integer
      add :metadata, :map, default: %{}
      add :active, :boolean, default: true
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:ai_participants, [:conversation_id])
    create index(:ai_participants, [:provider])
    create index(:ai_participants, [:active])
  end
end
```

### 5. Create the conversation_relationships table:

```elixir
# priv/repo/migrations/TIMESTAMP_create_conversation_relationships.exs
defmodule Peer2peer.Repo.Migrations.CreateConversationRelationships do
  use Ecto.Migration

  def change do
    create table(:conversation_relationships) do
      add :relationship_type, :string, null: false, default: "division"
      add :metadata, :map, default: %{}
      add :parent_id, references(:conversations, on_delete: :delete_all), null: false
      add :child_id, references(:conversations, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:conversation_relationships, [:parent_id])
    create index(:conversation_relationships, [:child_id])
    create unique_index(:conversation_relationships, [:parent_id, :child_id])

    # Prevent a conversation from having a relationship with itself
    create constraint("conversation_relationships", "no_self_relationships",
      check: "parent_id != child_id")
  end
end
```

### 6. Create the topics and conversation_topics tables:

```elixir
# priv/repo/migrations/TIMESTAMP_create_topics.exs
defmodule Peer2peer.Repo.Migrations.CreateTopics do
  use Ecto.Migration

  def change do
    create table(:topics) do
      add :name, :string, null: false
      add :description, :text
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:topics, [:name])
  end
end
```

```elixir
# priv/repo/migrations/TIMESTAMP_create_conversation_topics.exs
defmodule Peer2peer.Repo.Migrations.CreateConversationTopics do
  use Ecto.Migration

  def change do
    create table(:conversation_topics) do
      add :relevance, :float, null: false, default: 1.0
      add :detected_at, :utc_datetime, default: fragment("NOW()")
      add :metadata, :map, default: %{}
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :topic_id, references(:topics, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:conversation_topics, [:conversation_id])
    create index(:conversation_topics, [:topic_id])
    create unique_index(:conversation_topics, [:conversation_id, :topic_id])
  end
end
```

## Finally, let's create the context module for Conversations:

```elixir
# lib/peer2peer/conversations.ex
defmodule Peer2peer.Conversations do
  @moduledoc """
  The Conversations context: manages conversations, messages, AI participants,
  and the mitosis-based evolution of ideas within the system.
  """

  import Ecto.Query, warn: false
  alias Peer2peer.Repo

  alias Peer2peer.Accounts.User
  alias Peer2peer.Conversations.{
    Conversation,
    ConversationParticipant,
    Message,
    AIParticipant,
    ConversationRelationship,
    Topic,
    ConversationTopic
  }

  # Conversation functions

  def list_conversations(user) do
    query = from c in Conversation,
      join: p in ConversationParticipant, on: p.conversation_id == c.id,
      where: p.user_id == ^user.id,
      order_by: [desc: c.updated_at]

    Repo.all(query)
  end

  def get_conversation!(id), do: Repo.get!(Conversation, id)

  def get_conversation_with_participants!(id) do
    Conversation
    |> Repo.get!(id)
    |> Repo.preload([:participants, :ai_participants])
  end

  def create_conversation(attrs, creator) do
    %Conversation{}
    |> Conversation.changeset(Map.put(attrs, "creator_id", creator.id))
    |> Repo.insert()
    |> case do
      {:ok, conversation} ->
        # Automatically add creator as owner
        add_participant(conversation, creator, %{role: :owner, joined_at: DateTime.utc_now()})
        {:ok, conversation}
      error -> error
    end
  end

  def update_conversation(%Conversation{} = conversation, attrs) do
    conversation
    |> Conversation.changeset(attrs)
    |> Repo.update()
  end

  def delete_conversation(%Conversation{} = conversation) do
    Repo.delete(conversation)
  end

  def change_conversation_phase(%Conversation{} = conversation, new_phase) do
    conversation
    |> Conversation.phase_transition_changeset(new_phase)
    |> Repo.update()
  end

  def update_phase_progress(%Conversation{} = conversation, progress) do
    conversation
    |> Conversation.update_progress_changeset(progress)
    |> Repo.update()
  end

  # Participant functions

  def add_participant(conversation, user, attrs \\ %{}) do
    %ConversationParticipant{}
    |> ConversationParticipant.changeset(
      Map.merge(attrs, %{
        user_id: user.id,
        conversation_id: conversation.id,
        joined_at: Map.get(attrs, :joined_at, DateTime.utc_now())
      })
    )
    |> Repo.insert()
  end

  def remove_participant(conversation, user) do
    from(p in ConversationParticipant,
      where: p.conversation_id == ^conversation.id and p.user_id == ^user.id)
    |> Repo.delete_all()
  end

  def list_participants(conversation) do
    query = from p in ConversationParticipant,
      where: p.conversation_id == ^conversation.id,
      preload: [:user]

    Repo.all(query)
  end

  # Message functions

  def list_messages(conversation, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    include_ai = Keyword.get(opts, :include_ai, true)

    query = from m in Message,
      where: m.conversation_id == ^conversation.id,
      order_by: [desc: m.inserted_at],
      limit: ^limit,
      offset: ^offset

    query = if include_ai do
      query |> preload([:user, :ai_participant])
    else
      from m in query,
        where: not is_nil(m.user_id),
        preload: [:user]
    end

    Repo.all(query)
  end

  def get_message!(id), do: Repo.get!(Message, id)

  def create_message(%{user: user, conversation: conversation} = params) do
    attrs = Map.take(params, [:content, :message_type, :metadata, :parent_id])

    %Message{}
    |> Message.changeset(
      Map.merge(attrs, %{
        conversation_id: conversation.id,
        user_id: user.id,
        is_ai_generated: false
      })
    )
    |> Repo.insert()
  end

  def create_ai_message(%{ai_participant: ai, conversation: conversation} = params) do
    attrs = Map.take(params, [:content, :message_type, :metadata, :parent_id])

    %Message{}
    |> Message.changeset(
      Map.merge(attrs, %{
        conversation_id: conversation.id,
        ai_participant_id: ai.id,
        is_ai_generated: true
      })
    )
    |> Repo.insert()
  end

  # AI Participant functions

  def list_ai_participants(conversation) do
    query = from a in AIParticipant,
      where: a.conversation_id == ^conversation.id

    Repo.all(query)
  end

  def get_ai_participant!(id), do: Repo.get!(AIParticipant, id)

  def create_ai_participant(attrs, conversation) do
    %AIParticipant{}
    |> AIParticipant.changeset(Map.put(attrs, "conversation_id", conversation.id))
    |> Repo.insert()
  end

  def update_ai_participant(%AIParticipant{} = ai_participant, attrs) do
    ai_participant
    |> AIParticipant.changeset(attrs)
    |> Repo.update()
  end

  def delete_ai_participant(%AIParticipant{} = ai_participant) do
    Repo.delete(ai_participant)
  end

  # Conversation Relationship (Mitosis) functions

  def create_conversation_division(parent_conversation, division_attrs) do
    Repo.transaction(fn ->
      # 1. Create the child conversation
      {:ok, child_conversation} = create_conversation(
        Map.put(division_attrs, "creator_id", parent_conversation.creator_id),
        Repo.get!(User, parent_conversation.creator_id)
      )

      # 2. Create the relationship between parent and child
      {:ok, relationship} = %ConversationRelationship{}
      |> ConversationRelationship.changeset(%{
        relationship_type: :division,
        parent_id: parent_conversation.id,
        child_id: child_conversation.id,
        metadata: Map.get(division_attrs, "metadata", %{})
      })
      |> Repo.insert()

      # 3. Update parent conversation status to reflect division
      {:ok, _updated_parent} = update_conversation(parent_conversation, %{
        status: :divided,
        mitosis_phase: :telophase,
        phase_progress: 1.0
      })

      # Return the child conversation and relationship
      {child_conversation, relationship}
    end)
  end

  def get_parent_conversations(conversation) do
    query = from c in Conversation,
      join: r in ConversationRelationship, on: r.parent_id == c.id,
      where: r.child_id == ^conversation.id

    Repo.all(query)
  end

  def get_child_conversations(conversation) do
    query = from c in Conversation,
      join: r in ConversationRelationship, on: r.child_id == c.id,
      where: r.parent_id == ^conversation.id

    Repo.all(query)
  end

  # Topic functions

  def list_topics do
    Repo.all(Topic)
  end

  def get_topic!(id), do: Repo.get!(Topic, id)

  def create_topic(attrs) do
    %Topic{}
    |> Topic.changeset(attrs)
    |> Repo.insert()
  end

  def add_topic_to_conversation(conversation, topic, attrs \\ %{}) do
    %ConversationTopic{}
    |> ConversationTopic.changeset(
      Map.merge(attrs, %{
        conversation_id: conversation.id,
        topic_id: topic.id,
        detected_at: Map.get(attrs, :detected_at, DateTime.utc_now())
      })
    )
    |> Repo.insert()
  end

  def list_topics_for_conversation(conversation) do
    query = from t in Topic,
      join: ct in ConversationTopic, on: ct.topic_id == t.id,
      where: ct.conversation_id == ^conversation.id,
      order_by: [desc: ct.relevance]

    Repo.all(query)
  end
end
```

These schemas and migrations provide a comprehensive foundation for your P2P Idea Chat System, supporting:

1. Conversations with mitosis phases
2. User participation and roles
3. Message threading and types
4. AI participants with configurable behavior
5. Parent/child relationships between conversations for mitosis tracking
6. Topic tracking and relevance

The design allows conversations to evolve through the mitosis phases, with proper tracking of the process from prophase to telophase. The relationships between conversations are maintained to support the biological metaphor, and the AI integration is flexible enough to support different providers and models.

This architecture will enable you to implement the visual interfaces and interactions needed for your innovative chat concept based on cellular division.
