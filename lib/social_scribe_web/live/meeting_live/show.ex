defmodule SocialScribeWeb.MeetingLive.Show do
  use SocialScribeWeb, :live_view

  import SocialScribeWeb.PlatformLogo
  import SocialScribeWeb.ClipboardButton

  alias SocialScribe.Meetings
  alias SocialScribe.Automations

  @impl true
  def mount(%{"id" => meeting_id}, _session, socket) do
    meeting = Meetings.get_meeting_with_details(meeting_id)
    user_id = socket.assigns.current_user.id

    user_has_content_automations =
      Automations.list_active_user_automations_by_type(user_id, :content_generation)
      |> length()
      |> Kernel.>(0)

    user_has_contact_automations =
      Automations.list_active_user_automations_by_type(user_id, :update_contact)
      |> length()
      |> Kernel.>(0)

    content_results =
      Automations.list_automation_results_for_meeting_by_type(meeting_id, :content_generation)

    contact_update_results =
      Automations.list_automation_results_for_meeting_by_type(meeting_id, :update_contact)

    if meeting.calendar_event.user_id != user_id do
      socket =
        socket
        |> put_flash(:error, "You do not have permission to view this meeting.")
        |> redirect(to: ~p"/dashboard/meetings")

      {:error, socket}
    else
      socket =
        socket
        |> assign(:page_title, "Meeting Details: #{meeting.title}")
        |> assign(:meeting, meeting)
        |> assign(:content_results, content_results)
        |> assign(:contact_update_results, contact_update_results)
        |> assign(:user_has_content_automations, user_has_content_automations)
        |> assign(:user_has_contact_automations, user_has_contact_automations)
        |> assign(
          :follow_up_email_form,
          to_form(%{
            "follow_up_email" => ""
          })
        )

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"automation_result_id" => automation_result_id}, _uri, socket) do
    automation_result = Automations.get_automation_result!(automation_result_id)
    automation = Automations.get_automation!(automation_result.automation_id)

    socket =
      socket
      |> assign(:automation_result, automation_result)
      |> assign(:automation, automation)

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate-follow-up-email", params, socket) do
    socket =
      socket
      |> assign(:follow_up_email_form, to_form(params))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:search_contacts, query, component_id}, socket) do
    case get_hubspot_token(socket.assigns.current_user) do
      nil ->
        send_update(SocialScribeWeb.MeetingLive.ContactUpdateFormComponent,
          id: component_id,
          contacts: [],
          loading_contacts: false
        )

      token ->
        # Pass nil for empty search to get all contacts, otherwise pass the query
        search_query = if query == "" or is_nil(query), do: nil, else: query

        case SocialScribe.HubSpotApi.list_contacts(token, search_query) do
          {:ok, contacts} ->
            send_update(SocialScribeWeb.MeetingLive.ContactUpdateFormComponent,
              id: component_id,
              contacts: contacts,
              loading_contacts: false
            )

          {:error, _} ->
            send_update(SocialScribeWeb.MeetingLive.ContactUpdateFormComponent,
              id: component_id,
              contacts: [],
              loading_contacts: false
            )
        end
    end

    {:noreply, socket}
  end

  def handle_info({:close_dropdown, component_id}, socket) do
    send_update(SocialScribeWeb.MeetingLive.ContactUpdateFormComponent,
      id: component_id,
      close_dropdown: true
    )

    {:noreply, socket}
  end

  defp get_hubspot_token(user) do
    case SocialScribe.Accounts.get_user_credential_by_provider(user.id, "hubspot") do
      nil -> nil
      credential -> credential.token
    end
  end

  defp format_duration(nil), do: "N/A"

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    cond do
      minutes > 0 && remaining_seconds > 0 -> "#{minutes} min #{remaining_seconds} sec"
      minutes > 0 -> "#{minutes} min"
      seconds > 0 -> "#{seconds} sec"
      true -> "Less than a second"
    end
  end

  attr :meeting_transcript, :map, required: true

  defp transcript_content(assigns) do
    has_transcript =
      assigns.meeting_transcript &&
        assigns.meeting_transcript.content &&
        Map.get(assigns.meeting_transcript.content, "data") &&
        Enum.any?(Map.get(assigns.meeting_transcript.content, "data"))

    assigns =
      assigns
      |> assign(:has_transcript, has_transcript)

    ~H"""
    <div class="bg-white shadow-xl rounded-lg p-6 md:p-8">
      <h2 class="text-2xl font-semibold mb-4 text-slate-700">
        Meeting Transcript
      </h2>
      <div class="prose prose-sm sm:prose max-w-none h-96 overflow-y-auto pr-2">
        <%= if @has_transcript do %>
          <div :for={segment <- @meeting_transcript.content["data"]} class="mb-3">
            <p>
              <span class="font-semibold text-indigo-600">
                {segment["speaker"] || "Unknown Speaker"}:
              </span>
              {Enum.map_join(segment["words"] || [], " ", & &1["text"])}
            </p>
          </div>
        <% else %>
          <p class="text-slate-500">
            Transcript not available for this meeting.
          </p>
        <% end %>
      </div>
    </div>
    """
  end
end
