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

# lib/hello/appointments/appointment.ex
defmodule Hello.Appointments.Appointment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "appointments" do
    field :customer_name, :string
    field :customer_email, :string
    field :customer_phone, :string
    field :notes, :string
    field :status, :string, default: "confirmed"

    belongs_to :time_slot, Hello.Appointments.TimeSlot

    timestamps()
  end

  def changeset(appointment, attrs) do
    appointment
    |> cast(attrs, [
      :customer_name,
      :customer_email,
      :customer_phone,
      :notes,
      :status,
      :time_slot_id
    ])
    |> validate_required([:customer_name, :customer_email, :time_slot_id])
    |> validate_format(:customer_email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_inclusion(:status, ["confirmed", "cancelled", "completed"])
  end
end
