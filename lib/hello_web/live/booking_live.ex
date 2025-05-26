# lib/hello_web/live/booking_live.ex
defmodule HelloWeb.BookingLive do
  use HelloWeb, :live_view

  alias Hello.Appointments
  alias Hello.Appointments.Appointment

  @impl true
  def mount(_params, _session, socket) do
    available_slots = Appointments.list_available_time_slots()

    socket =
      socket
      |> assign(:available_slots, available_slots)
      |> assign(:selected_slot, nil)
      |> assign(:form, to_form(Appointments.change_appointment(%Appointment{})))
      |> assign(:booking_step, :select_time)
      |> assign(:success_message, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_slot", %{"slot_id" => slot_id}, socket) do
    slot_id = String.to_integer(slot_id)
    selected_slot = Enum.find(socket.assigns.available_slots, &(&1.id == slot_id))

    socket =
      socket
      |> assign(:selected_slot, selected_slot)
      |> assign(:booking_step, :enter_details)

    {:noreply, socket}
  end

  def handle_event("back_to_selection", _params, socket) do
    # Refresh available slots in case something changed
    available_slots = Appointments.list_available_time_slots()

    socket =
      socket
      |> assign(:available_slots, available_slots)
      |> assign(:selected_slot, nil)
      |> assign(:booking_step, :select_time)
      |> assign(:form, to_form(Appointments.change_appointment(%Appointment{})))

    {:noreply, socket}
  end

  def handle_event("book_appointment", %{"appointment" => appointment_params}, socket) do
    case Appointments.book_appointment(socket.assigns.selected_slot.id, appointment_params) do
      {:ok, appointment} ->
        socket =
          socket
          |> assign(:booking_step, :success)
          |> assign(:success_message, "Your appointment has been booked successfully!")
          |> assign(:booked_appointment, appointment |> Hello.Repo.preload(:time_slot))

        {:noreply, socket}

      {:error, :slot_not_available} ->
        socket =
          socket
          |> put_flash(
            :error,
            "Sorry, this time slot is no longer available. Please select another time."
          )
          |> assign(:booking_step, :select_time)
          |> assign(:available_slots, Appointments.list_available_time_slots())

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("book_another", _params, socket) do
    available_slots = Appointments.list_available_time_slots()

    socket =
      socket
      |> assign(:available_slots, available_slots)
      |> assign(:selected_slot, nil)
      |> assign(:form, to_form(Appointments.change_appointment(%Appointment{})))
      |> assign(:booking_step, :select_time)
      |> assign(:success_message, nil)

    {:noreply, socket}
  end

  defp format_datetime(datetime) do
    datetime
    |> NaiveDateTime.to_string()
    |> String.replace("T", " at ")
    |> String.slice(0, 19)
  end

  defp format_field_value(nil), do: ""
  defp format_field_value(value) when is_binary(value), do: value
  defp format_field_value(_), do: ""

  defp format_date(datetime) do
    date = NaiveDateTime.to_date(datetime)
    Calendar.strftime(date, "%A, %B %d, %Y")
  end

  defp format_time(datetime) do
    time = NaiveDateTime.to_time(datetime)
    Calendar.strftime(time, "%I:%M %p")
  end

  defp group_slots_by_date(slots) do
    slots
    |> Enum.group_by(&NaiveDateTime.to_date(&1.start_time))
    |> Enum.sort_by(fn {date, _slots} -> date end)
  end
end
