defmodule SocialScribeWeb.MeetingLive.ContactUpdateFormComponent do
  use SocialScribeWeb, :live_component

  alias SocialScribe.HubSpotApi
  alias SocialScribe.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl font-semibold">
      <div class="mb-6">
        <h2 class="text-2xl font-bold text-gray-900 mb-2">Update in HubSpot</h2>
        <p class="text-gray-500 text-lg mt-1 font-medium">
          Here are suggested updates to sync with your integrations based on this meeting
        </p>
      </div>

      <div class="mb-6">
        <label class="block text-slate-700 mb-2">Select Contact</label>
        <div class="relative">
          <%= if @selected_contact && !@show_contact_dropdown do %>
            <div
              class="flex items-center gap-3 px-2 py-1.5 border-2 border-slate-200 rounded-xl cursor-pointer"
              phx-click="open_dropdown"
              phx-target={@myself}
            >
              <div class="w-7 h-7 rounded-full bg-slate-300 flex items-center justify-center text-sm font-semibold text-slate-700">
                {get_initials(@selected_contact)}
              </div>
              <div class="flex-1">
                <span class="font-medium text-slate-700">
                  {@selected_contact.firstname} {@selected_contact.lastname}
                </span>
                <%= if Map.get(@selected_contact, :is_sample, false) do %>
                  <span class="text-gray-500"> (Sample Contact)</span>
                <% end %>
              </div>
              <button type="button" class="text-gray-400 hover:text-gray-600">
                <.icon name="hero-chevron-up-down" class="h-7 w-7" />
              </button>
            </div>
          <% else %>
            <div class="relative">
              <form phx-change="search_contacts" phx-target={@myself} phx-submit="search_contacts">
                <input
                  type="text"
                  name="contact_search"
                  placeholder="Search contacts..."
                  value={@contact_search}
                  phx-debounce="300"
                  phx-focus="open_dropdown"
                  phx-blur="close_dropdown_delayed"
                  phx-target={@myself}
                  autocomplete="off"
                  class="w-full pl-10 pr-2 py-2 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 bg-white"
                />
              </form>
              <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <.icon name="hero-magnifying-glass" class="h-5 w-5 text-gray-400" />
              </div>
            </div>

            <%= if @show_contact_dropdown do %>
              <div class="absolute z-10 mt-1 w-full bg-white border border-gray-200 rounded-xl shadow-lg max-h-60 overflow-auto">
                <%= if @loading_contacts do %>
                  <div class="px-4 py-3 text-sm text-gray-500">Loading contacts...</div>
                <% else %>
                  <%= if Enum.empty?(@contacts) do %>
                    <div class="px-4 py-3 text-sm text-gray-500">No contacts found</div>
                  <% else %>
                    <div
                      :for={contact <- @contacts}
                      class="px-4 py-3 hover:bg-gray-50 cursor-pointer flex items-center gap-3"
                      phx-click="select_contact"
                      phx-value-id={contact.id}
                      phx-target={@myself}
                    >
                      <div class="w-9 h-9 rounded-full bg-slate-200 flex items-center justify-center text-sm font-semibold text-slate-600">
                        {get_initials(contact)}
                      </div>
                      <div>
                        <div class="font-medium text-slate-700">
                          {contact.firstname} {contact.lastname}
                        </div>
                        <div class="text-sm text-gray-500 me-8">{contact.email}</div>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <div class="space-y-3 max-h-120 overflow-y-auto pr-1">
        <%= for {group_name, fields} <- @grouped_updates do %>
          <div class="bg-[#f5f8f6] rounded-xl overflow-hidden px-2 py-3">
            <div class="flex items-center justify-between px-4 py-3">
              <div class="flex items-center gap-3">
                <input
                  type="checkbox"
                  checked={group_selected?(@selected_fields, fields)}
                  phx-click="toggle_group_selection"
                  phx-value-group={group_name}
                  phx-target={@myself}
                  class="w-4 h-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                />
                <span class="font-semibold text-slate-800">{group_name}</span>
              </div>
              <div class="flex items-center gap-3">
                <span class="text-sm text-gray-700 bg-gray-200 px-3 py-1 rounded-full font-bold">
                  {count_selected(fields, @selected_fields)} update{if count_selected(
                                                                         fields,
                                                                         @selected_fields
                                                                       ) != 1,
                                                                       do: "s"} selected
                </span>
                <button
                  type="button"
                  class="text-sm text-gray-500 hover:text-gray-700 font-medium"
                  phx-click="toggle_group"
                  phx-value-group={group_name}
                  phx-target={@myself}
                >
                  {if group_name in @expanded_groups, do: "Hide details", else: "Show details"}
                </button>
              </div>
            </div>

            <%= if group_name in @expanded_groups do %>
              <div class="px-4 pb-4 pt-2 border-dashed border-blue-200">
                <%= for field <- fields do %>
                  <div class="mb-4 last:mb-0">
                    <div class="grid grid-cols-[auto_1fr_auto_1fr] items-center gap-x-3 gap-y-2">
                      <%!-- Row 1: Field name spanning columns 2-4 --%>
                      <div></div>
                      <div class="text-sm font-semibold text-gray-700 col-span-3">
                        {field.field_name}
                      </div>
                      <%!-- Row 2: Checkbox, old value, arrow, new value --%>
                      <input
                        type="checkbox"
                        checked={field.field_id in @selected_fields}
                        phx-click="toggle_field"
                        phx-value-field-id={field.field_id}
                        phx-target={@myself}
                        class="w-4 h-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                      />
                      <% existing_val = get_existing_value(@selected_contact, field.field_id) %>
                      <input
                        type="text"
                        value={existing_val}
                        placeholder="No existing value"
                        disabled
                        class={"px-2 py-1.5 border-2 border-gray-200 rounded-lg bg-white text-gray-500 #{if existing_val, do: "line-through"}"}
                      />
                      <span class="text-gray-400">
                        <.icon name="hero-arrow-long-right" class="h-5 w-5" />
                      </span>
                      <input
                        type="text"
                        value={field.suggested_value}
                        disabled
                        class="px-2 py-1.5 border-2 border-gray-200 rounded-lg bg-white text-gray-700"
                      />
                      <%!-- Row 3: Empty, Update mapping, Empty, Found in transcript --%>
                      <div></div>
                      <button
                        type="button"
                        class="text-sm text-blue-600 hover:text-blue-800 font-medium text-left"
                      >
                        Update mapping
                      </button>
                      <div></div>
                      <%= if field.transcript_timestamp do %>
                        <span class="text-sm text-gray-500 font-medium text-left">
                          Found in transcript ({field.transcript_timestamp})
                        </span>
                      <% else %>
                        <div></div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%= if Enum.empty?(@suggested_updates) do %>
        <div class="text-center py-8 text-gray-500">
          No suggested updates found for this meeting.
        </div>
      <% end %>

      <div class="mt-6 pt-4 border-t border-gray-200">
        <div class="flex items-center justify-between">
          <span class="text-sm text-gray-500">
            {length(@selected_fields)} field{if length(@selected_fields) != 1, do: "s"} selected to update
          </span>
          <div class="flex gap-3">
            <button
              type="button"
              phx-click={JS.patch(@patch)}
              class="px-4 py-2 border-2 border-gray-300 rounded-lg text-slate-700 hover:bg-gray-50 font-medium"
            >
              Cancel
            </button>
            <button
              type="button"
              phx-click="update_contact"
              phx-target={@myself}
              disabled={is_nil(@selected_contact) || Enum.empty?(@selected_fields)}
              class="px-4 py-2 bg-emerald-500 text-white rounded-lg hover:bg-emerald-600 disabled:opacity-50 disabled:cursor-not-allowed font-medium"
            >
              Update HubSpot
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{contacts: contacts, loading_contacts: loading}, socket) when is_list(contacts) do
    # Handle send_update from parent LiveView for contact search results
    {:ok,
     socket
     |> assign(:contacts, contacts)
     |> assign(:loading_contacts, loading)
     |> assign(:show_contact_dropdown, true)}
  end

  def update(%{close_dropdown: true}, socket) do
    # Handle close dropdown request from parent LiveView
    {:ok, assign(socket, :show_contact_dropdown, false)}
  end

  def update(assigns, socket) do
    suggested_updates = parse_suggested_updates(assigns.automation_result.generated_content)
    grouped_updates = group_updates_by_category(suggested_updates)
    all_field_ids = Enum.map(suggested_updates, & &1.field_id)

    socket =
      socket
      |> assign(assigns)
      |> assign(:suggested_updates, suggested_updates)
      |> assign(:grouped_updates, grouped_updates)
      |> assign(:selected_fields, all_field_ids)
      |> assign(:expanded_groups, Map.keys(grouped_updates))
      |> assign(:contacts, [])
      |> assign(:selected_contact, nil)
      |> assign(:contact_search, "")
      |> assign(:show_contact_dropdown, false)
      |> assign(:loading_contacts, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("open_dropdown", _params, socket) do
    socket =
      assign(socket,
        loading_contacts: true,
        show_contact_dropdown: true
      )

    # Load all contacts when dropdown opens
    send(self(), {:search_contacts, nil, socket.assigns.id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("search_contacts", %{"contact_search" => query}, socket) do
    query = String.trim(query)

    socket =
      assign(socket,
        loading_contacts: true,
        show_contact_dropdown: true,
        contact_search: query
      )

    # Send message to parent LiveView to handle async contact search
    query_to_send = if query == "", do: nil, else: query
    send(self(), {:search_contacts, query_to_send, socket.assigns.id})
    {:noreply, socket}
  end

  def handle_event("select_contact", %{"id" => contact_id}, socket) do
    contact = Enum.find(socket.assigns.contacts, &(&1.id == contact_id))

    {:noreply,
     assign(socket,
       selected_contact: contact,
       show_contact_dropdown: false,
       contact_search: ""
     )}
  end

  @impl true
  def handle_event("clear_contact", _params, socket) do
    {:noreply, assign(socket, selected_contact: nil)}
  end

  @impl true
  def handle_event("close_dropdown_delayed", _params, socket) do
    # Small delay to allow clicking on dropdown items before it closes
    Process.send_after(self(), {:close_dropdown, socket.assigns.id}, 200)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_group", %{"group" => group_name}, socket) do
    expanded = socket.assigns.expanded_groups

    new_expanded =
      if group_name in expanded do
        Enum.reject(expanded, &(&1 == group_name))
      else
        [group_name | expanded]
      end

    {:noreply, assign(socket, expanded_groups: new_expanded)}
  end

  @impl true
  def handle_event("toggle_group_selection", %{"group" => group_name}, socket) do
    fields = Map.get(socket.assigns.grouped_updates, group_name, [])
    field_ids = Enum.map(fields, & &1.field_id)
    currently_selected = socket.assigns.selected_fields

    all_selected? = Enum.all?(field_ids, &(&1 in currently_selected))

    new_selected =
      if all_selected? do
        Enum.reject(currently_selected, &(&1 in field_ids))
      else
        Enum.uniq(currently_selected ++ field_ids)
      end

    {:noreply, assign(socket, selected_fields: new_selected)}
  end

  @impl true
  def handle_event("toggle_field", %{"field-id" => field_id}, socket) do
    selected = socket.assigns.selected_fields

    new_selected =
      if field_id in selected do
        Enum.reject(selected, &(&1 == field_id))
      else
        [field_id | selected]
      end

    {:noreply, assign(socket, selected_fields: new_selected)}
  end

  @impl true
  def handle_event("update_contact", _params, socket) do
    contact = socket.assigns.selected_contact
    selected_fields = socket.assigns.selected_fields
    updates = socket.assigns.suggested_updates

    properties =
      updates
      |> Enum.filter(&(&1.field_id in selected_fields))
      |> Enum.map(&{&1.field_id, &1.suggested_value})
      |> Map.new()

    case get_hubspot_token(socket.assigns.current_user) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Please connect your HubSpot account first.")
         |> push_patch(to: socket.assigns.patch)}

      token ->
        case HubSpotApi.update_contact(token, contact.id, properties) do
          {:ok, _updated_contact} ->
            {:noreply,
             socket
             |> put_flash(:info, "Contact updated successfully in HubSpot.")
             |> push_patch(to: socket.assigns.patch)}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to update contact in HubSpot.")
             |> push_patch(to: socket.assigns.patch)}
        end
    end
  end

  defp parse_suggested_updates(nil), do: []
  defp parse_suggested_updates(""), do: []

  defp parse_suggested_updates(content) when is_binary(content) do
    # Clean markdown code blocks if present
    cleaned =
      content
      |> String.replace(~r/```json\s*/, "")
      |> String.replace(~r/```\s*/, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, updates} when is_list(updates) ->
        Enum.map(updates, fn update ->
          %{
            field_id: Map.get(update, "field_id", ""),
            field_name: Map.get(update, "field_name", ""),
            suggested_value: Map.get(update, "suggested_value", ""),
            transcript_timestamp: Map.get(update, "transcript_timestamp")
          }
        end)

      _ ->
        []
    end
  end

  defp group_updates_by_category(updates) do
    updates
    |> Enum.group_by(&get_category/1)
    |> Enum.into(%{})
  end

  defp get_category(%{field_id: field_id}) do
    case field_id do
      f when f in ["firstname", "lastname"] -> "Client name"
      "phone" -> "Phone number"
      "email" -> "Email address"
      "address" -> "Address"
      "date_of_birth" -> "Birthday"
      "company" -> "Employment"
      _ -> "Other"
    end
  end

  defp get_initials(nil), do: "?"

  defp get_initials(%{firstname: nil, lastname: nil}), do: "?"

  defp get_initials(%{firstname: firstname, lastname: lastname}) do
    first = if firstname, do: String.first(firstname), else: ""
    last = if lastname, do: String.first(lastname), else: ""
    String.upcase("#{first}#{last}")
  end

  defp group_selected?(selected_fields, fields) do
    field_ids = Enum.map(fields, & &1.field_id)
    Enum.all?(field_ids, &(&1 in selected_fields))
  end

  defp count_selected(fields, selected_fields) do
    Enum.count(fields, &(&1.field_id in selected_fields))
  end

  defp get_existing_value(nil, _field_id), do: nil

  defp get_existing_value(contact, field_id) do
    value = Map.get(contact, String.to_existing_atom(field_id))
    if is_nil(value) || value == "", do: nil, else: value
  rescue
    _ -> nil
  end

  defp get_hubspot_token(user) do
    case Accounts.get_user_credential_by_provider(user.id, "hubspot") do
      nil -> nil
      credential -> credential.token
    end
  end
end
