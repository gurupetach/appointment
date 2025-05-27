# lib/hello/appointments/time_slot.ex
defmodule Hello.Appointments.TimeSlot do
  use Ecto.Schema
  import Ecto.Changeset

  schema "time_slots" do
    field :start_time, :naive_datetime
    field :end_time, :naive_datetime
    field :is_available, :boolean, default: true
    field :admin_notes, :string

    has_one :appointment, Hello.Appointments.Appointment

    timestamps()
  end

  def changeset(time_slot, attrs) do
    time_slot
    |> cast(attrs, [:start_time, :end_time, :is_available, :admin_notes])
    |> validate_required([:start_time, :end_time])
    |> validate_time_order()
  end

  defp validate_time_order(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if start_time && end_time && NaiveDateTime.compare(start_time, end_time) != :lt do
      add_error(changeset, :end_time, "must be after start time")
    else
      changeset
    end
  end
end
