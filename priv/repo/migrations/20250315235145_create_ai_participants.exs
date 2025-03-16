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
