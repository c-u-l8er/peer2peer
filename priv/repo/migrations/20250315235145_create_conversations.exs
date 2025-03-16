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
