defmodule Hello.Repo.Migrations.CreateAvailability do
  use Ecto.Migration

  def change do
    create table(:weekly_availability) do
      # monday, tuesday, etc.
      add :day_of_week, :string, null: false
      add :is_enabled, :boolean, default: true, null: false
      # Store JSON array of time slots
      add :time_slots, :map, default: %{}
      # For multi-admin support later
      add :admin_id, :integer

      timestamps()
    end

    create unique_index(:weekly_availability, [:day_of_week, :admin_id])
    create index(:weekly_availability, [:is_enabled])
  end
end
