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
             check: "parent_id != child_id"
           )
  end
end
