# Create the migration file
# Run: mix ecto.gen.migration create_appointments_and_time_slots

defmodule Hello.Repo.Migrations.CreateAppointmentsAndTimeSlots do
  use Ecto.Migration

  def change do
    # Admin-defined available time slots
    create table(:time_slots) do
      add :start_time, :naive_datetime, null: false
      add :end_time, :naive_datetime, null: false
      add :is_available, :boolean, default: true, null: false
      add :admin_notes, :text

      timestamps()
    end

    # User bookings
    create table(:appointments) do
      add :time_slot_id, references(:time_slots, on_delete: :delete_all), null: false
      add :customer_name, :string, null: false
      add :customer_email, :string, null: false
      add :customer_phone, :string
      add :notes, :text
      add :status, :string, default: "confirmed", null: false

      timestamps()
    end

    create index(:time_slots, [:start_time])
    create index(:time_slots, [:is_available])
    # One booking per slot
    create unique_index(:appointments, [:time_slot_id])
  end
end
