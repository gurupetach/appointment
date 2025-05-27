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
    # Load availability from database or use defaults
    availability =
      case Appointments.get_weekly_availability() do
        empty_map when map_size(empty_map) == 0 ->
          # Initialize with defaults if database is empty - using 4-digit military time
          default_availability = %{
            "monday" => %{enabled: true, hours: [%{"start" => "0900", "end" => "1700"}]},
            "tuesday" => %{enabled: true, hours: [%{"start" => "0900", "end" => "1700"}]},
            "wednesday" => %{enabled: true, hours: [%{"start" => "0900", "end" => "1700"}]},
            "thursday" => %{enabled: true, hours: [%{"start" => "0900", "end" => "1700"}]},
            "friday" => %{enabled: true, hours: [%{"start" => "0900", "end" => "1700"}]},
            "saturday" => %{enabled: false, hours: []},
            "sunday" => %{enabled: false, hours: []}
          }

          # Save defaults to database
          Task.start(fn -> Appointments.save_weekly_availability(default_availability) end)
          default_availability

        existing_availability ->
          # Convert existing colon format to 4-digit format
          convert_availability_to_military_time(existing_availability)
      end

    socket =
      socket
      |> assign(:days_of_week, @days_of_week)
      |> assign(:availability, availability)
      |> assign(:timezone, "East Africa Time")
      |> assign(:saving, false)
      # Track unsaved changes
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
            do: [%{"start" => "0900", "end" => "0930"}],
            else: current_day.hours
          )
    }

    updated_availability = Map.put(availability, day, updated_day)

    socket =
      socket
      |> assign(:availability, updated_availability)
      |> save_to_database(updated_availability)

    {:noreply, socket}
  end

  def handle_event("update_start_time", params, socket) do
    %{"day" => day, "index" => index, "field" => "start", "value" => value} = params

    IO.inspect(params, label: "Update Start Time Event")

    availability = socket.assigns.availability
    day_data = Map.get(availability, day)
    index = String.to_integer(index)

    # Calculate default end time (start time + 30 minutes)
    default_end_time = add_minutes_to_time(value, 30)

    updated_hours =
      List.update_at(day_data.hours, index, fn hour ->
        # If end time is not set or is before the new start time, set default end time
        current_end = hour["end"]

        new_end =
          if current_end == nil or current_end == "" or
               time_minutes(current_end) <= time_minutes(value) do
            default_end_time
          else
            current_end
          end

        updated = %{hour | "start" => value, "end" => new_end}
        IO.inspect(updated, label: "Updated Hour with Auto End Time")
        updated
      end)

    updated_day = %{day_data | hours: updated_hours}
    updated_availability = Map.put(availability, day, updated_day)

    socket =
      socket
      |> assign(:availability, updated_availability)
      |> save_to_database_and_regenerate_slots(updated_availability)

    {:noreply, socket}
  end

  def handle_event("update_end_time", params, socket) do
    %{"day" => day, "index" => index, "field" => "end", "value" => value} = params

    IO.inspect(params, label: "Update End Time Event")

    availability = socket.assigns.availability
    day_data = Map.get(availability, day)
    index = String.to_integer(index)

    updated_hours =
      List.update_at(day_data.hours, index, fn hour ->
        updated = Map.put(hour, "end", value)
        IO.inspect(updated, label: "Updated Hour End Time")
        updated
      end)

    updated_day = %{day_data | hours: updated_hours}
    updated_availability = Map.put(availability, day, updated_day)

    socket =
      socket
      |> assign(:availability, updated_availability)
      |> save_to_database_and_regenerate_slots(updated_availability)

    {:noreply, socket}
  end

  def handle_event("toggle_day", %{"day" => day}, socket) do
    availability = socket.assigns.availability
    current_day = Map.get(availability, day)

    updated_day = %{
      current_day
      | enabled: !current_day.enabled,
        hours:
          if(!current_day.enabled,
            do: [%{"start" => "0900", "end" => "0930"}],
            else: current_day.hours
          )
    }

    updated_availability = Map.put(availability, day, updated_day)

    socket =
      socket
      |> assign(:availability, updated_availability)
      |> save_to_database_and_regenerate_slots(updated_availability)

    {:noreply, socket}
  end

  def handle_event("add_hours", %{"day" => day}, socket) do
    availability = socket.assigns.availability
    day_data = Map.get(availability, day)

    # Find next available time slot
    existing_hours = day_data.hours
    next_start = find_next_available_start(existing_hours)
    # Default 30 minutes slot
    next_end = add_minutes_to_time(next_start, 30)

    new_hour = %{"start" => next_start, "end" => next_end}
    updated_hours = day_data.hours ++ [new_hour]
    updated_day = %{day_data | hours: updated_hours}
    updated_availability = Map.put(availability, day, updated_day)

    socket =
      socket
      |> assign(:availability, updated_availability)
      |> save_to_database_and_regenerate_slots(updated_availability)

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
      |> save_to_database_and_regenerate_slots(updated_availability)

    {:noreply, socket}
  end

  # Replace the old save_to_database function with this comprehensive one:
  defp save_to_database_and_regenerate_slots(socket, availability) do
    socket = assign(socket, :saving, true)

    # Save to database and regenerate time slots in background
    Task.start(fn ->
      case Appointments.save_weekly_availability(availability) do
        {:ok, _} ->
          # After saving weekly availability, regenerate actual time slots
          case Appointments.regenerate_time_slots_from_availability() do
            {:ok, count} ->
              send(self(), {:save_complete, :success, count})

            {:error, reason} ->
              send(self(), {:save_complete, {:error, reason}})
          end

        {:error, reason} ->
          send(self(), {:save_complete, {:error, reason}})
      end
    end)

    socket
  end

  @impl true
  def handle_info({:save_complete, :success, slot_count}, socket) do
    socket =
      socket
      |> assign(:saving, false)
      |> put_flash(:info, "Availability saved and #{slot_count} time slots regenerated!")

    {:noreply, socket}
  end

  def handle_info({:save_complete, {:error, reason}}, socket) do
    socket =
      socket
      |> assign(:saving, false)
      |> put_flash(:error, "Failed to save: #{inspect(reason)}")

    {:noreply, socket}
  end

  def handle_event("save_slot", %{"day" => day, "index" => index}, socket) do
    # Remove from pending changes since we're saving manually
    pending_changes = Map.delete(socket.assigns.pending_changes, "#{day}-#{index}")

    socket =
      socket
      |> assign(:pending_changes, pending_changes)
      |> put_flash(:info, "Time slot saved successfully")

    {:noreply, socket}
  end

  def handle_event("add_hours", %{"day" => day}, socket) do
    availability = socket.assigns.availability
    day_data = Map.get(availability, day)

    # Find next available time slot
    existing_hours = day_data.hours
    next_start = find_next_available_start(existing_hours)
    # Default 30 minutes slot
    next_end = add_minutes_to_time(next_start, 30)

    new_hour = %{"start" => next_start, "end" => next_end}
    updated_hours = day_data.hours ++ [new_hour]
    updated_day = %{day_data | hours: updated_hours}
    updated_availability = Map.put(availability, day, updated_day)

    socket =
      socket
      |> assign(:availability, updated_availability)
      |> save_to_database(updated_availability)

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
      |> save_to_database(updated_availability)

    {:noreply, socket}
  end

  def handle_event("generate_slots", _params, socket) do
    case Appointments.create_time_slots_from_availability() do
      {:ok, count} ->
        socket = put_flash(socket, :info, "Generated #{count} time slots successfully!")
        {:noreply, socket}

      {:error, message} ->
        socket = put_flash(socket, :error, message)
        {:noreply, socket}
    end
  end

  # Save to database functionality - saves on every change
  defp save_to_database(socket, availability) do
    socket = assign(socket, :saving, true)

    # Save to database in background
    Task.start(fn ->
      case Appointments.save_weekly_availability(availability) do
        {:ok, _} ->
          send(self(), {:save_complete, :success})

        {:error, reason} ->
          send(self(), {:save_complete, {:error, reason}})
      end
    end)

    socket
  end

  @impl true
  def handle_info({:save_complete, :success}, socket) do
    socket =
      socket
      |> assign(:saving, false)
      |> put_flash(:info, "Changes saved to database")

    {:noreply, socket}
  end

  def handle_info({:save_complete, {:error, reason}}, socket) do
    socket =
      socket
      |> assign(:saving, false)
      |> put_flash(:error, "Failed to save: #{inspect(reason)}")

    {:noreply, socket}
  end

  # Helper functions
  defp convert_availability_to_military_time(availability) do
    Enum.into(availability, %{}, fn {day, day_data} ->
      converted_hours =
        Enum.map(day_data.hours, fn hour ->
          %{
            "start" => convert_time_to_military(hour["start"]),
            "end" => convert_time_to_military(hour["end"])
          }
        end)

      {day, %{day_data | hours: converted_hours}}
    end)
  end

  defp convert_time_to_military(time_string) when is_binary(time_string) do
    case String.length(time_string) do
      # Already in military format
      4 ->
        time_string

      _ ->
        case String.split(time_string, ":") do
          [hour_str, minute_str] ->
            "#{String.pad_leading(hour_str, 2, "0")}#{String.pad_leading(minute_str, 2, "0")}"

          _ ->
            time_string
        end
    end
  end

  defp convert_time_to_military(_), do: "0000"

  defp find_next_available_start(existing_hours) when existing_hours == [], do: "0900"

  defp find_next_available_start(existing_hours) do
    latest_end =
      existing_hours
      |> Enum.map(& &1["end"])
      |> Enum.filter(&(&1 != nil))
      |> Enum.sort()
      |> List.last()

    case latest_end do
      nil -> "0900"
      # 30 minute gap
      time -> add_minutes_to_time(time, 30)
    end
  end

  defp add_minutes_to_time(time_string, minutes_to_add) do
    # Handle both 4-digit and colon format
    {hour, minute} =
      case String.length(time_string) do
        4 ->
          {h, m} = String.split_at(time_string, 2)
          {String.to_integer(h), String.to_integer(m)}

        _ ->
          [hour_str, minute_str] = String.split(time_string, ":")
          {String.to_integer(hour_str), String.to_integer(minute_str)}
      end

    total_minutes = hour * 60 + minute + minutes_to_add
    new_hour = div(total_minutes, 60)
    new_minute = rem(total_minutes, 60)

    # Cap at 23:30 and format as 4-digit
    if new_hour >= 24 do
      "2330"
    else
      "#{String.pad_leading("#{new_hour}", 2, "0")}#{String.pad_leading("#{new_minute}", 2, "0")}"
    end
  end

  defp format_time_options do
    0..23
    |> Enum.flat_map(fn hour ->
      [
        %{
          value: "#{String.pad_leading("#{hour}", 2, "0")}00",
          label: "#{String.pad_leading("#{hour}", 2, "0")}00"
        },
        %{
          value: "#{String.pad_leading("#{hour}", 2, "0")}30",
          label: "#{String.pad_leading("#{hour}", 2, "0")}30"
        }
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
        |> Enum.map(fn option ->
          is_available = not time_conflicts_with_ranges?(option.value, nil, used_ranges)
          Map.put(option, :available, is_available)
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
          |> Enum.map(fn option ->
            is_valid_end = time_minutes(option.value) > time_minutes(current_start)

            is_available =
              is_valid_end and
                not time_conflicts_with_ranges?(current_start, option.value, used_ranges)

            Map.put(option, :available, is_available)
          end)
        else
          format_time_options()
          |> Enum.map(fn option -> Map.put(option, :available, true) end)
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
    case String.length(time_string) do
      4 ->
        # Handle 4-digit format like "0900", "1730"
        {hour, minute} = time_string |> String.split_at(2)
        String.to_integer(hour) * 60 + String.to_integer(minute)

      _ ->
        # Handle colon format like "09:00", "17:30"
        case String.split(time_string, ":") do
          [hour_str, minute_str] ->
            String.to_integer(hour_str) * 60 + String.to_integer(minute_str)

          [hour_str] ->
            # Check if it's a 4-digit string without colon
            if String.length(hour_str) == 4 do
              {hour, minute} = String.split_at(hour_str, 2)
              String.to_integer(hour) * 60 + String.to_integer(minute)
            else
              0
            end

          _ ->
            0
        end
    end
  end

  defp format_time_display(time_string) when is_binary(time_string) do
    case String.length(time_string) do
      # Already in 4-digit format like "0900"
      4 ->
        time_string

      _ ->
        # Convert from colon format to 4-digit
        case String.split(time_string, ":") do
          [hour_str, minute_str] ->
            "#{String.pad_leading(hour_str, 2, "0")}#{String.pad_leading(minute_str, 2, "0")}"

          _ ->
            time_string
        end
    end
  end

  defp format_time_display(_), do: "----"

  defp has_pending_changes?(pending_changes, day, index) do
    Map.has_key?(pending_changes, "#{day}-#{index}")
  end

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
end
