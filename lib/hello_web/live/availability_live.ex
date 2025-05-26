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
    # Initialize default availability
    default_availability = %{
      "monday" => %{enabled: true, hours: [%{"start" => "09:00", "end" => "17:00"}]},
      "tuesday" => %{enabled: true, hours: [%{"start" => "09:00", "end" => "17:00"}]},
      "wednesday" => %{enabled: true, hours: [%{"start" => "09:00", "end" => "17:00"}]},
      "thursday" => %{enabled: true, hours: [%{"start" => "09:00", "end" => "17:00"}]},
      "friday" => %{enabled: true, hours: [%{"start" => "09:00", "end" => "17:00"}]},
      "saturday" => %{enabled: false, hours: []},
      "sunday" => %{enabled: false, hours: []}
    }

    socket =
      socket
      |> assign(:days_of_week, @days_of_week)
      |> assign(:availability, default_availability)
      |> assign(:timezone, "East Africa Time")
      |> assign(:saving, false)
      |> assign(:pending_changes, %{})

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
          if(!current_day.enabled,
            do: [%{"start" => "09:00", "end" => "17:00"}],
            else: current_day.hours
          )
    }

    updated_availability = Map.put(availability, day, updated_day)

    socket =
      socket
      |> assign(:availability, updated_availability)
      |> auto_save()

    {:noreply, socket}
  end

  def handle_event("update_time", params, socket) do
    %{"day" => day, "index" => index, "field" => field, "value" => value} = params

    IO.inspect(params, label: "Update Time Event")

    availability = socket.assigns.availability
    day_data = Map.get(availability, day)
    index = String.to_integer(index)

    updated_hours =
      List.update_at(day_data.hours, index, fn hour ->
        updated = Map.put(hour, field, value)
        IO.inspect(updated, label: "Updated Hour")
        updated
      end)

    updated_day = %{day_data | hours: updated_hours}
    updated_availability = Map.put(availability, day, updated_day)

    socket =
      socket
      |> assign(:availability, updated_availability)
      |> auto_save()

    {:noreply, socket}
  end

  def handle_event("add_hours", %{"day" => day}, socket) do
    availability = socket.assigns.availability
    day_data = Map.get(availability, day)

    # Find next available time slot
    existing_hours = day_data.hours
    next_start = find_next_available_start(existing_hours)
    # Default 1 hour slot
    next_end = add_hours_to_time(next_start, 1)

    new_hour = %{"start" => next_start, "end" => next_end}
    updated_hours = day_data.hours ++ [new_hour]
    updated_day = %{day_data | hours: updated_hours}
    updated_availability = Map.put(availability, day, updated_day)

    socket =
      socket
      |> assign(:availability, updated_availability)
      |> auto_save()

    {:noreply, socket}
  end

  def handle_event("remove_hours", %{"day" => day, "index" => index}, socket) do
    availability = socket.assigns.availability
    day_data = Map.get(availability, day)
    index = String.to_integer(index)

    updated_hours = List.delete_at(day_data.hours, index)
    updated_day = %{day_data | hours: updated_hours}
    updated_availability = Map.put(availability, day, updated_day)

    socket =
      socket
      |> assign(:availability, updated_availability)
      |> auto_save()

    {:noreply, socket}
  end

  def handle_event("generate_slots", _params, socket) do
    case generate_time_slots_from_availability(socket.assigns.availability) do
      {:ok, count} ->
        socket = put_flash(socket, :info, "Generated #{count} time slots successfully!")
        {:noreply, socket}

      {:error, message} ->
        socket = put_flash(socket, :error, message)
        {:noreply, socket}
    end
  end

  # Auto-save functionality
  defp auto_save(socket) do
    socket = assign(socket, :saving, true)

    # Simulate save delay
    Process.send_after(self(), :save_complete, 500)

    socket
  end

  @impl true
  def handle_info(:save_complete, socket) do
    # Here you would actually save to database
    IO.inspect(socket.assigns.availability, label: "Saving Availability")

    socket =
      socket
      |> assign(:saving, false)
      |> put_flash(:info, "Availability saved automatically")

    {:noreply, socket}
  end

  # Helper functions
  defp find_next_available_start(existing_hours) when existing_hours == [], do: "09:00"

  defp find_next_available_start(existing_hours) do
    latest_end =
      existing_hours
      |> Enum.map(& &1["end"])
      |> Enum.filter(&(&1 != nil))
      |> Enum.sort()
      |> List.last()

    case latest_end do
      nil -> "09:00"
      # 30 minute gap
      time -> add_hours_to_time(time, 0.5)
    end
  end

  defp add_hours_to_time(time_string, hours_to_add) do
    [hour_str, minute_str] = String.split(time_string, ":")
    hour = String.to_integer(hour_str)
    minute = String.to_integer(minute_str)

    total_minutes = hour * 60 + minute + round(hours_to_add * 60)
    new_hour = div(total_minutes, 60)
    new_minute = rem(total_minutes, 60)

    # Cap at 23:30
    if new_hour >= 24 do
      "23:30"
    else
      "#{String.pad_leading("#{new_hour}", 2, "0")}:#{String.pad_leading("#{new_minute}", 2, "0")}"
    end
  end

  defp generate_time_slots_from_availability(availability) do
    enabled_days = Enum.count(availability, fn {_day, data} -> data.enabled end)
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

  defp get_available_times_for_field(day_availability, current_index, field, current_start \\ nil) do
    existing_hours = day_availability.hours

    case field do
      "start" ->
        # Get all used time ranges except current one
        used_ranges =
          existing_hours
          |> Enum.with_index()
          |> Enum.reject(fn {_hour, idx} -> idx == current_index end)
          |> Enum.map(fn {hour, _idx} -> {hour["start"], hour["end"]} end)

        format_time_options()
        |> Enum.filter(fn option ->
          not time_conflicts_with_ranges?(option.value, nil, used_ranges)
        end)

      "end" ->
        if current_start do
          # End time must be after start time and not conflict with other ranges
          used_ranges =
            existing_hours
            |> Enum.with_index()
            |> Enum.reject(fn {_hour, idx} -> idx == current_index end)
            |> Enum.map(fn {hour, _idx} -> {hour["start"], hour["end"]} end)

          format_time_options()
          |> Enum.filter(fn option ->
            time_minutes(option.value) > time_minutes(current_start) + 30 and
              not time_conflicts_with_ranges?(current_start, option.value, used_ranges)
          end)
        else
          format_time_options()
        end
    end
  end

  defp time_conflicts_with_ranges?(start_time, end_time, ranges) do
    Enum.any?(ranges, fn {range_start, range_end} ->
      cond do
        is_nil(end_time) ->
          # Just checking start time
          time_in_range?(start_time, range_start, range_end)

        is_nil(range_start) or is_nil(range_end) ->
          false

        true ->
          # Check if new range overlaps with existing range
          start_minutes = time_minutes(start_time)
          end_minutes = time_minutes(end_time)
          range_start_minutes = time_minutes(range_start)
          range_end_minutes = time_minutes(range_end)

          not (end_minutes <= range_start_minutes or start_minutes >= range_end_minutes)
      end
    end)
  end

  defp time_in_range?(time, range_start, range_end) do
    if range_start && range_end do
      time_minutes = time_minutes(time)
      start_minutes = time_minutes(range_start)
      end_minutes = time_minutes(range_end)

      time_minutes >= start_minutes and time_minutes < end_minutes
    else
      false
    end
  end

  defp time_minutes(time_string) do
    [hour_str, minute_str] = String.split(time_string, ":")
    String.to_integer(hour_str) * 60 + String.to_integer(minute_str)
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

  defp format_time_display(time_string) when is_binary(time_string) do
    case String.split(time_string, ":") do
      [hour_str, minute_str] ->
        hour = String.to_integer(hour_str)
        minute = String.to_integer(minute_str)
        format_12_hour(hour, minute)

      _ ->
        time_string
    end
  end

  defp format_time_display(_), do: "--:--"

  defp day_enabled?(availability, day_key) do
    Map.get(availability, day_key, %{enabled: false}).enabled
  end

  defp get_day_hours(availability, day_key) do
    Map.get(availability, day_key, %{hours: []}).hours
  end

  defp get_current_hour_value(hours, index, field) do
    case Enum.at(hours, index) do
      nil -> ""
      hour -> Map.get(hour, field, "")
    end
  end

  defp has_pending_changes?(pending_changes, day, index) do
    Map.has_key?(pending_changes, "#{day}-#{index}")
  end
end
