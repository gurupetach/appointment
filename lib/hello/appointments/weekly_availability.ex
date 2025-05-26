# lib/hello/appointments/weekly_availability.ex
defmodule Hello.Appointments.WeeklyAvailability do
  use Ecto.Schema
  import Ecto.Changeset

  @days_of_week ~w(monday tuesday wednesday thursday friday saturday sunday)

  schema "weekly_availability" do
    field :day_of_week, :string
    field :is_enabled, :boolean, default: true
    # Change to array of maps
    field :time_slots, {:array, :map}, default: []
    field :admin_id, :integer

    timestamps()
  end

  def changeset(availability, attrs) do
    availability
    |> cast(attrs, [:day_of_week, :is_enabled, :time_slots, :admin_id])
    |> validate_required([:day_of_week, :is_enabled])
    |> validate_inclusion(:day_of_week, @days_of_week)
    |> validate_time_slots()
    |> unique_constraint([:day_of_week, :admin_id])
  end

  defp validate_time_slots(changeset) do
    time_slots = get_change(changeset, :time_slots)

    if time_slots && is_list(time_slots) do
      valid_slots =
        Enum.all?(time_slots, fn slot ->
          is_map(slot) &&
            Map.has_key?(slot, "start") &&
            Map.has_key?(slot, "end") &&
            valid_time_format?(slot["start"]) &&
            valid_time_format?(slot["end"])
        end)

      if valid_slots do
        changeset
      else
        add_error(changeset, :time_slots, "invalid time slot format")
      end
    else
      # Allow empty lists
      if time_slots == [] or is_nil(time_slots) do
        changeset
      else
        add_error(changeset, :time_slots, "time_slots must be a list of maps")
      end
    end
  end

  defp valid_time_format?(time_string) when is_binary(time_string) do
    case String.length(time_string) do
      4 ->
        # Validate 4-digit format like "0900", "1730"
        case String.split_at(time_string, 2) do
          {hour_str, minute_str} ->
            case {Integer.parse(hour_str), Integer.parse(minute_str)} do
              {{hour, ""}, {minute, ""}}
              when hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59 ->
                true

              _ ->
                false
            end

          _ ->
            false
        end

      _ ->
        # Validate colon format like "09:00", "17:30"
        case String.split(time_string, ":") do
          [hour_str, minute_str] ->
            case {Integer.parse(hour_str), Integer.parse(minute_str)} do
              {{hour, ""}, {minute, ""}}
              when hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59 ->
                true

              _ ->
                false
            end

          _ ->
            false
        end
    end
  end

  defp valid_time_format?(_), do: false
end
