# lib/hello/appointments.ex
defmodule Hello.Appointments do
  @moduledoc """
  The Appointments context.
  """

  import Ecto.Query, warn: false
  alias Hello.Repo
  alias Hello.Appointments.{TimeSlot, Appointment}

  alias Hello.Appointments.WeeklyAvailability
  @days_of_week ~w(monday tuesday wednesday thursday friday saturday sunday)

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

  # Weekly Availability Functions
  def get_weekly_availability(admin_id \\ nil) do
    query =
      if admin_id do
        from w in WeeklyAvailability,
          where: w.admin_id == ^admin_id,
          order_by: [asc: w.day_of_week]
      else
        from w in WeeklyAvailability,
          where: is_nil(w.admin_id),
          order_by: [asc: w.day_of_week]
      end

    availability_records = Repo.all(query)

    # Convert to the format expected by LiveView
    @days_of_week
    |> Enum.map(fn day ->
      case Enum.find(availability_records, &(&1.day_of_week == day)) do
        nil ->
          {day, %{enabled: false, hours: []}}

        record ->
          # time_slots should now be a list from the database
          time_slots = record.time_slots || []
          {day, %{enabled: record.is_enabled, hours: time_slots}}
      end
    end)
    |> Enum.into(%{})
  end

  def save_weekly_availability(availability_map, admin_id \\ nil) do
    Repo.transaction(fn ->
      Enum.each(availability_map, fn {day, day_data} ->
        # Use proper query for nil admin_id
        existing =
          if admin_id do
            Repo.get_by(WeeklyAvailability, day_of_week: day, admin_id: admin_id)
          else
            Repo.one(
              from w in WeeklyAvailability, where: w.day_of_week == ^day and is_nil(w.admin_id)
            )
          end

        case existing do
          nil ->
            %WeeklyAvailability{}
            |> WeeklyAvailability.changeset(%{
              day_of_week: day,
              is_enabled: day_data.enabled,
              time_slots: day_data.hours,
              admin_id: admin_id
            })
            |> Repo.insert!()

          existing_record ->
            existing_record
            |> WeeklyAvailability.changeset(%{
              is_enabled: day_data.enabled,
              time_slots: day_data.hours
            })
            |> Repo.update!()
        end
      end)
    end)
  end

  def create_time_slots_from_availability(admin_id \\ nil) do
    availability = get_weekly_availability(admin_id)
    today = Date.utc_today()

    # Generate slots for next 8 weeks
    # 8 weeks * 7 days
    slots_created =
      0..55
      |> Enum.map(&Date.add(today, &1))
      |> Enum.flat_map(fn date ->
        day_name = date |> Date.day_of_week() |> day_number_to_name()
        day_availability = Map.get(availability, day_name, %{enabled: false, hours: []})

        if day_availability.enabled do
          create_slots_for_day(date, day_availability.hours)
        else
          []
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> length()

    {:ok, slots_created}
  end

  # In lib/hello/appointments.ex, replace create_slots_for_day:

  defp create_slots_for_day(date, hours) when is_list(hours) do
    Enum.map(hours, fn hour_slot ->
      # Safely extract start and end times
      start_time = safe_get_time(hour_slot, "start")
      end_time = safe_get_time(hour_slot, "end")

      if start_time && end_time do
        start_datetime = combine_date_time(date, start_time)
        end_datetime = combine_date_time(date, end_time)

        # Check if slot already exists to avoid duplicates
        existing = Repo.get_by(TimeSlot, start_time: start_datetime, end_time: end_datetime)

        if existing do
          existing
        else
          case create_time_slot(%{
                 start_time: start_datetime,
                 end_time: end_datetime,
                 is_available: true,
                 admin_notes: "Auto-generated from weekly availability"
               }) do
            {:ok, slot} -> slot
            {:error, _} -> nil
          end
        end
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp create_slots_for_day(_date, _hours), do: []

  # Add this helper function to safely extract time values:
  defp safe_get_time(hour_slot, field) when is_map(hour_slot) do
    case Map.get(hour_slot, field) do
      time_string when is_binary(time_string) -> time_string
      time_list when is_list(time_list) -> List.first(time_list)
      _ -> nil
    end
  end

  defp safe_get_time(_, _), do: nil

  defp combine_date_time(date, time_string) when is_binary(time_string) do
    # Handle 4-digit military time format
    {hour, minute} =
      case String.length(time_string) do
        4 ->
          {h, m} = String.split_at(time_string, 2)
          {String.to_integer(h), String.to_integer(m)}

        _ ->
          [hour_str, minute_str] = String.split(time_string, ":")
          {String.to_integer(hour_str), String.to_integer(minute_str)}
      end

    {:ok, datetime} = NaiveDateTime.new(date, ~T[00:00:00])
    NaiveDateTime.add(datetime, hour * 3600 + minute * 60, :second)
  end

  # Handle when time_string is a list (fix the error)
  defp combine_date_time(date, time_list) when is_list(time_list) do
    time_string = List.first(time_list) || "0900"
    combine_date_time(date, time_string)
  end

  # Handle nil or other types
  defp combine_date_time(date, _), do: combine_date_time(date, "0900")

  defp day_number_to_name(day_number) do
    case day_number do
      1 -> "monday"
      2 -> "tuesday"
      3 -> "wednesday"
      4 -> "thursday"
      5 -> "friday"
      6 -> "saturday"
      7 -> "sunday"
    end
  end

  def regenerate_time_slots_from_availability(admin_id \\ nil) do
    # Delete existing auto-generated slots to avoid duplicates
    from(ts in TimeSlot, where: ts.admin_notes == "Auto-generated from weekly availability")
    |> Repo.delete_all()

    # Generate fresh slots from current availability
    create_time_slots_from_availability(admin_id)
  end

  def delete_auto_generated_slots() do
    from(ts in TimeSlot, where: ts.admin_notes == "Auto-generated from weekly availability")
    |> Repo.delete_all()
  end
end
