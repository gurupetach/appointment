# lib/hello_web/live/admin_live.ex
defmodule HelloWeb.AdminLive do
  use HelloWeb, :live_view

  alias Hello.Appointments
  alias Hello.Appointments.TimeSlot

  @impl true
  def mount(_params, _session, socket) do
    time_slots = Appointments.list_time_slots()

    socket =
      socket
      |> assign(:time_slots, time_slots)
      |> assign(:form, to_form(Appointments.change_time_slot(%TimeSlot{})))
      |> assign(:editing, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("create_slot", %{"time_slot" => time_slot_params}, socket) do
    case Appointments.create_time_slot(time_slot_params) do
      {:ok, _time_slot} ->
        time_slots = Appointments.list_time_slots()

        socket =
          socket
          |> assign(:time_slots, time_slots)
          |> assign(:form, to_form(Appointments.change_time_slot(%TimeSlot{})))
          |> put_flash(:info, "Time slot created successfully!")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("edit_slot", %{"id" => id}, socket) do
    time_slot = Appointments.get_time_slot!(id)
    form = to_form(Appointments.change_time_slot(time_slot))

    socket =
      socket
      |> assign(:editing, String.to_integer(id))
      |> assign(:form, form)

    {:noreply, socket}
  end

  def handle_event("update_slot", %{"time_slot" => time_slot_params}, socket) do
    time_slot = Appointments.get_time_slot!(socket.assigns.editing)

    case Appointments.update_time_slot(time_slot, time_slot_params) do
      {:ok, _time_slot} ->
        time_slots = Appointments.list_time_slots()

        socket =
          socket
          |> assign(:time_slots, time_slots)
          |> assign(:form, to_form(Appointments.change_time_slot(%TimeSlot{})))
          |> assign(:editing, nil)
          |> put_flash(:info, "Time slot updated successfully!")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    socket =
      socket
      |> assign(:editing, nil)
      |> assign(:form, to_form(Appointments.change_time_slot(%TimeSlot{})))

    {:noreply, socket}
  end

  def handle_event("delete_slot", %{"id" => id}, socket) do
    time_slot = Appointments.get_time_slot!(id)
    {:ok, _} = Appointments.delete_time_slot(time_slot)

    time_slots = Appointments.list_time_slots()

    socket =
      socket
      |> assign(:time_slots, time_slots)
      |> put_flash(:info, "Time slot deleted successfully!")

    {:noreply, socket}
  end

  def handle_event("toggle_availability", %{"id" => id}, socket) do
    time_slot = Appointments.get_time_slot!(id)
    {:ok, _} = Appointments.update_time_slot(time_slot, %{is_available: !time_slot.is_available})

    time_slots = Appointments.list_time_slots()
    {:noreply, assign(socket, :time_slots, time_slots)}
  end

  defp format_datetime(datetime) do
    datetime
    |> NaiveDateTime.to_string()
    |> String.replace("T", " at ")
    |> String.slice(0, 19)
  end

  defp format_for_input(nil), do: ""

  defp format_for_input(%NaiveDateTime{} = datetime) do
    NaiveDateTime.to_string(datetime) |> String.slice(0, 16)
  end

  defp format_for_input(value) when is_binary(value), do: value
  defp format_for_input(_), do: ""

  defp format_for_textarea(nil), do: ""
  defp format_for_textarea(value) when is_binary(value), do: value
  defp format_for_textarea(_), do: ""

  defp slot_status(slot) do
    cond do
      slot.appointment -> "Booked"
      slot.is_available -> "Available"
      true -> "Unavailable"
    end
  end

  defp status_class(slot) do
    cond do
      slot.appointment -> "text-red-600 bg-red-100"
      slot.is_available -> "text-green-600 bg-green-100"
      true -> "text-gray-600 bg-gray-100"
    end
  end
end
