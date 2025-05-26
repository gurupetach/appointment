# lib/hello_web/live/availability_live.ex
defmodule HelloWeb.AvailabilityLive do
  use HelloWeb, :live_view

  alias Hello.Appointments

  @days_of_week [
    %{key: "monday", label: "Monday", short: "M"},
    %{key: "tuesday", label: "Tuesday", short: "T"},
    %{key: "wednesday", label: "Wednesday", short: "W"},
    %{key: "thursday", label: "Thursday", short: "T"},
    %{key: "friday", label: "Friday", short: "F"},
    %{key: "saturday", label: "Saturday", short: "S"},
    %{key: "sunday", label: "Sunday", short: "S"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    # Initialize default availability (9 AM to 5 PM, Monday to Friday)
    default_availability = %{
      "monday" => %{enabled: true, hours: [%{start: "09:00", end: "17:00"}]},
      "tuesday" => %{enabled: true, hours: [%{start: "09:00", end: "17:00"}]},
      "wednesday" => %{enabled: true, hours: [%{start: "09:00", end: "17:00"}]},
      "thursday" => %{enabled: true, hours: [%{start: "09:00", end: "17:00"}]},
      "friday" => %{enabled: true, hours: [%{start: "09:00", end: "17:00"}]},
      "saturday" => %{enabled: false, hours: []},
      "sunday" => %{enabled: false, hours: []}
    }

    socket =
      socket
      |> assign(:days_of_week, @days_of_week)
      |> assign(:availability, default_availability)
      |> assign(:timezone, "East Africa Time")

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_day", %{"day" => day}, socket) do
    availability = socket.assigns.availability
    current_day = Map.get(availability, day)

    updated_day = %{
      current_day
      | enabled: !current_day.enabled,
        hours:
          if(!current_day.enabled, do: [%{start: "09:00", end: "17:00"}], else: current_day.hours)
    }

    updated_availability = Map.put(availability, day, updated_day)

    {:noreply, assign(socket, :availability, updated_availability)}
  end

  def handle_event(
        "update_hours",
        %{"day" => day, "index" => index, "field" => field, "value" => value},
        socket
      ) do
    IO.inspect({day, index, field, value}, label: "Update Hours Event")

    availability = socket.assigns.availability
    day_data = Map.get(availability, day)
    index = String.to_integer(index)

    updated_hours =
      List.update_at(day_data.hours, index, fn hour ->
        updated_hour = Map.put(hour, field, value)
        IO.inspect(updated_hour, label: "Updated Hour")
        updated_hour
      end)

    updated_day = %{day_data | hours: updated_hours}
    updated_availability = Map.put(availability, day, updated_day)

    IO.inspect(updated_availability, label: "Updated Availability")

    {:noreply, assign(socket, :availability, updated_availability)}
  end

  def handle_event("add_hours", %{"day" => day}, socket) do
    availability = socket.assigns.availability
    day_data = Map.get(availability, day)

    new_hour = %{start: "09:00", end: "17:00"}
    updated_hours = day_data.hours ++ [new_hour]
    updated_day = %{day_data | hours: updated_hours}
    updated_availability = Map.put(availability, day, updated_day)

    {:noreply, assign(socket, :availability, updated_availability)}
  end

  def handle_event("remove_hours", %{"day" => day, "index" => index}, socket) do
    availability = socket.assigns.availability
    day_data = Map.get(availability, day)
    index = String.to_integer(index)

    updated_hours = List.delete_at(day_data.hours, index)
    updated_day = %{day_data | hours: updated_hours}
    updated_availability = Map.put(availability, day, updated_day)

    {:noreply, assign(socket, :availability, updated_availability)}
  end

  def handle_event("save_availability", _params, socket) do
    # Here you would save to database
    # For now, we'll just show a success message
    socket = put_flash(socket, :info, "Availability updated successfully!")
    {:noreply, socket}
  end

  def handle_event("generate_slots", _params, socket) do
    # Generate time slots based on availability
    case generate_time_slots_from_availability(socket.assigns.availability) do
      {:ok, count} ->
        socket = put_flash(socket, :info, "Generated #{count} time slots successfully!")
        {:noreply, socket}

      {:error, message} ->
        socket = put_flash(socket, :error, message)
        {:noreply, socket}
    end
  end

  defp generate_time_slots_from_availability(availability) do
    # This would generate actual time slots based on the weekly availability
    # For now, just return a success count
    enabled_days = Enum.count(availability, fn {_day, data} -> data.enabled end)
    # Simulate 8 slots per day
    {:ok, enabled_days * 8}
  end

  defp format_time_options do
    0..23
    |> Enum.flat_map(fn hour ->
      [
        %{value: "#{String.pad_leading("#{hour}", 2, "0")}:00", label: format_12_hour(hour, 0)},
        %{value: "#{String.pad_leading("#{hour}", 2, "0")}:30", label: format_12_hour(hour, 30)}
      ]
    end)
  end

  defp get_valid_end_times(start_time) do
    case start_time do
      nil ->
        format_time_options()

      "" ->
        format_time_options()

      start_time ->
        [start_hour, start_minute] =
          String.split(start_time, ":") |> Enum.map(&String.to_integer/1)

        start_minutes = start_hour * 60 + start_minute

        format_time_options()
        |> Enum.filter(fn option ->
          [end_hour, end_minute] =
            String.split(option.value, ":") |> Enum.map(&String.to_integer/1)

          end_minutes = end_hour * 60 + end_minute
          # At least 30 minutes difference
          end_minutes > start_minutes + 30
        end)
    end
  end

  defp format_12_hour(hour, minute) do
    period = if hour < 12, do: "AM", else: "PM"

    display_hour =
      case hour do
        0 -> 12
        h when h > 12 -> h - 12
        h -> h
      end

    minute_str = String.pad_leading("#{minute}", 2, "0")
    "#{display_hour}:#{minute_str} #{period}"
  end

  defp format_time_display(time_string) do
    case String.split(time_string, ":") do
      [hour_str, minute_str] ->
        hour = String.to_integer(hour_str)
        minute = String.to_integer(minute_str)
        format_12_hour(hour, minute)

      _ ->
        time_string
    end
  end

  defp day_enabled?(availability, day_key) do
    Map.get(availability, day_key, %{enabled: false}).enabled
  end

  defp get_day_hours(availability, day_key) do
    Map.get(availability, day_key, %{hours: []}).hours
  end
end
