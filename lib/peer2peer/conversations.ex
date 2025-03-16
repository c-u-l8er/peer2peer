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
    query =
      from c in Conversation,
        join: p in ConversationParticipant,
        on: p.conversation_id == c.id,
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

      {:error, changeset} ->
        {:error, changeset}
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
      where: p.conversation_id == ^conversation.id and p.user_id == ^user.id
    )
    |> Repo.delete_all()
  end

  def list_participants(conversation) do
    query =
      from p in ConversationParticipant,
        where: p.conversation_id == ^conversation.id,
        preload: [:user]

    Repo.all(query)
  end

  # Message functions

  def list_messages(conversation, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    include_ai = Keyword.get(opts, :include_ai, true)

    query =
      from m in Message,
        where: m.conversation_id == ^conversation.id,
        order_by: [desc: m.inserted_at],
        limit: ^limit,
        offset: ^offset

    query =
      if include_ai do
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
    query =
      from a in AIParticipant,
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
      {:ok, child_conversation} =
        create_conversation(
          Map.put(division_attrs, "creator_id", parent_conversation.creator_id),
          Repo.get!(User, parent_conversation.creator_id)
        )

      # 2. Create the relationship between parent and child
      {:ok, relationship} =
        %ConversationRelationship{}
        |> ConversationRelationship.changeset(%{
          relationship_type: :division,
          parent_id: parent_conversation.id,
          child_id: child_conversation.id,
          metadata: Map.get(division_attrs, "metadata", %{})
        })
        |> Repo.insert()

      # 3. Update parent conversation status to reflect division
      {:ok, _updated_parent} =
        update_conversation(parent_conversation, %{
          status: :divided,
          mitosis_phase: :telophase,
          phase_progress: 1.0
        })

      # Return the child conversation and relationship
      {child_conversation, relationship}
    end)
  end

  def get_parent_conversations(conversation) do
    query =
      from c in Conversation,
        join: r in ConversationRelationship,
        on: r.parent_id == c.id,
        where: r.child_id == ^conversation.id

    Repo.all(query)
  end

  def get_child_conversations(conversation) do
    query =
      from c in Conversation,
        join: r in ConversationRelationship,
        on: r.child_id == c.id,
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
    query =
      from t in Topic,
        join: ct in ConversationTopic,
        on: ct.topic_id == t.id,
        where: ct.conversation_id == ^conversation.id,
        order_by: [desc: ct.relevance]

    Repo.all(query)
  end
end
