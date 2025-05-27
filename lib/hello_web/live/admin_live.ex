# lib/hello_web/live/admin_live.ex
defmodule HelloWeb.AdminLive do
  use HelloWeb, :live_view

  alias Hello.Appointments

  @impl true
  def mount(_params, _session, socket) do
    time_slots = Appointments.list_time_slots()
    appointments = Appointments.list_appointments()

    socket =
      socket
      |> assign(:time_slots, time_slots)
      |> assign(:appointments, appointments)

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "create_slot",
        %{"time_slot" => time_slot_params, "duration" => duration},
        socket
      ) do
    start_time = parse_datetime(time_slot_params["start_time"])
    duration_minutes = String.to_integer(duration)
    end_time = NaiveDateTime.add(start_time, duration_minutes * 60, :second)

    slot_params = %{
      start_time: start_time,
      end_time: end_time,
      is_available: true,
      admin_notes: "Created via admin dashboard"
    }

    case Appointments.create_time_slot(slot_params) do
      {:ok, _time_slot} ->
        time_slots = Appointments.list_time_slots()

        socket =
          socket
          |> assign(:time_slots, time_slots)
          |> put_flash(:info, "Time slot created successfully!")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          put_flash(socket, :error, "Failed to create time slot: #{format_errors(changeset)}")

        {:noreply, socket}
    end
  end

  def handle_event("delete_slot", %{"id" => id}, socket) do
    time_slot = Appointments.get_time_slot!(id)

    case Appointments.delete_time_slot(time_slot) do
      {:ok, _} ->
        time_slots = Appointments.list_time_slots()

        socket =
          socket
          |> assign(:time_slots, time_slots)
          |> put_flash(:info, "Time slot deleted successfully!")

        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to delete time slot")
        {:noreply, socket}
    end
  end

  # Helper functions for template
  defp count_available_slots(time_slots) do
    now = NaiveDateTime.utc_now()

    time_slots
    |> Enum.filter(fn slot ->
      slot.is_available &&
        NaiveDateTime.compare(slot.start_time, now) == :gt &&
        is_nil(slot.appointment)
    end)
    |> length()
  end

  defp count_today_appointments(appointments) do
    today = Date.utc_today()

    appointments
    |> Enum.filter(fn appointment ->
      appointment_date = NaiveDateTime.to_date(appointment.time_slot.start_time)
      Date.compare(appointment_date, today) == :eq
    end)
    |> length()
  end

  defp count_unique_customers(appointments) do
    appointments
    |> Enum.map(& &1.customer_email)
    |> Enum.uniq()
    |> length()
  end

  defp get_upcoming_slots(time_slots) do
    now = NaiveDateTime.utc_now()

    time_slots
    |> Enum.filter(fn slot ->
      NaiveDateTime.compare(slot.start_time, now) == :gt
    end)
    |> Enum.sort_by(& &1.start_time, NaiveDateTime)
  end

  defp format_datetime_short(datetime) do
    date = NaiveDateTime.to_date(datetime)
    today = Date.utc_today()
    tomorrow = Date.add(today, 1)

    case Date.compare(date, today) do
      :eq -> "Today"
      :gt when date == tomorrow -> "Tomorrow"
      _ -> Calendar.strftime(date, "%b %d")
    end
  end

  defp format_time_range(start_time, end_time) do
    start_time_str = Calendar.strftime(start_time, "%H:%M")
    end_time_str = Calendar.strftime(end_time, "%H:%M")
    "#{start_time_str} - #{end_time_str}"
  end

  defp parse_datetime(datetime_string) do
    case NaiveDateTime.from_iso8601(datetime_string <> ":00") do
      {:ok, datetime} ->
        datetime

      {:error, _} ->
        # Fallback to current time if parsing fails
        NaiveDateTime.utc_now()
    end
  end

  defp format_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field} #{message}" end)
    |> Enum.join(", ")
  end
end
