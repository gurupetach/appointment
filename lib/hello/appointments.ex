# lib/hello/appointments.ex
defmodule Hello.Appointments do
  @moduledoc """
  The Appointments context.
  """

  import Ecto.Query, warn: false
  alias Hello.Repo
  alias Hello.Appointments.{TimeSlot, Appointment}

  ## Time Slots

  def list_time_slots do
    Repo.all(from t in TimeSlot, order_by: [asc: t.start_time], preload: [:appointment])
  end

  def list_available_time_slots do
    now = NaiveDateTime.utc_now()

    Repo.all(
      from t in TimeSlot,
        left_join: a in Appointment,
        on: a.time_slot_id == t.id,
        where: t.is_available == true and t.start_time > ^now and is_nil(a.id),
        order_by: [asc: t.start_time]
    )
  end

  def get_time_slot!(id), do: Repo.get!(TimeSlot, id)

  def create_time_slot(attrs \\ %{}) do
    %TimeSlot{}
    |> TimeSlot.changeset(attrs)
    |> Repo.insert()
  end

  def update_time_slot(%TimeSlot{} = time_slot, attrs) do
    time_slot
    |> TimeSlot.changeset(attrs)
    |> Repo.update()
  end

  def delete_time_slot(%TimeSlot{} = time_slot) do
    Repo.delete(time_slot)
  end

  def change_time_slot(%TimeSlot{} = time_slot, attrs \\ %{}) do
    TimeSlot.changeset(time_slot, attrs)
  end

  ## Appointments

  def list_appointments do
    Repo.all(from a in Appointment, order_by: [desc: a.inserted_at], preload: [:time_slot])
  end

  def get_appointment!(id), do: Repo.get!(Appointment, id) |> Repo.preload(:time_slot)

  def create_appointment(attrs \\ %{}) do
    %Appointment{}
    |> Appointment.changeset(attrs)
    |> Repo.insert()
  end

  def update_appointment(%Appointment{} = appointment, attrs) do
    appointment
    |> Appointment.changeset(attrs)
    |> Repo.update()
  end

  def delete_appointment(%Appointment{} = appointment) do
    Repo.delete(appointment)
  end

  def change_appointment(%Appointment{} = appointment, attrs \\ %{}) do
    Appointment.changeset(appointment, attrs)
  end

  def book_appointment(time_slot_id, customer_attrs) do
    time_slot = get_time_slot!(time_slot_id)

    # Check if slot is still available
    case list_available_time_slots() |> Enum.find(&(&1.id == time_slot_id)) do
      nil ->
        {:error, :slot_not_available}

      _slot ->
        customer_attrs
        |> Map.put("time_slot_id", time_slot_id)
        |> create_appointment()
    end
  end
end
