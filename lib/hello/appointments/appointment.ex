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
