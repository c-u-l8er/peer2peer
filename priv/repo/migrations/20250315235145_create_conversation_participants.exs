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
