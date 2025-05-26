defmodule Hello.Repo.Migrations.ChangeTimeSlotsToArray do
  use Ecto.Migration

  def up do
    # First, add a new temporary column
    alter table(:weekly_availability) do
      add :time_slots_temp, {:array, :map}, default: []
    end

    # Convert existing data
    execute """
    UPDATE weekly_availability
    SET time_slots_temp = CASE
      WHEN time_slots IS NULL OR time_slots = '{}' THEN ARRAY[]::jsonb[]
      ELSE ARRAY[time_slots]
    END
    """

    # Drop the old column and rename the new one
    alter table(:weekly_availability) do
      remove :time_slots
    end

    rename table(:weekly_availability), :time_slots_temp, to: :time_slots
  end

  def down do
    # Convert back to single jsonb
    alter table(:weekly_availability) do
      add :time_slots_temp, :map, default: %{}
    end

    execute """
    UPDATE weekly_availability
    SET time_slots_temp = CASE
      WHEN time_slots IS NULL OR array_length(time_slots, 1) IS NULL THEN '{}'::jsonb
      WHEN array_length(time_slots, 1) = 1 THEN time_slots[1]
      ELSE time_slots[1]
    END
    """

    alter table(:weekly_availability) do
      remove :time_slots
    end

    rename table(:weekly_availability), :time_slots_temp, to: :time_slots
  end
end
