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
