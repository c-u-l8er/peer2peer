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
             check: "(user_id IS NOT NULL) OR (ai_participant_id IS NOT NULL)"
           )
  end
end
