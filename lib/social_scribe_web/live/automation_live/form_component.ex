defmodule SocialScribeWeb.AutomationLive.FormComponent do
  use SocialScribeWeb, :live_component

  alias SocialScribe.Automations
  alias SocialScribe.Automations.Automation

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage automation records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="automation-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input
          field={@form[:type]}
          type="select"
          label="Type"
          prompt="Select automation type"
          options={type_options()}
        />
        <.input
          field={@form[:platform]}
          type="select"
          label="Platform"
          prompt="Select platform"
          options={platform_options_for_type(@selected_type)}
        />
        <div :if={@selected_type == :content_generation}>
          <.input field={@form[:description]} type="textarea" label="Description" />
          <.input field={@form[:example]} type="textarea" label="Example" />
        </div>
        <:actions>
          <.button phx-disable-with="Saving...">Save Automation</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{automation: automation} = assigns, socket) do
    changeset = Automations.change_automation(automation)
    selected_type = automation.type || Ecto.Changeset.get_field(changeset, :type)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:selected_type, selected_type)
     |> assign_new(:form, fn -> to_form(changeset) end)}
  end

  @impl true
  def handle_event("validate", %{"automation" => automation_params}, socket) do
    selected_type = parse_type(automation_params["type"])

    # For update_contact, set predefined description and example
    params =
      automation_params
      |> Map.put("user_id", socket.assigns.current_user.id)
      |> maybe_set_update_contact_fields(selected_type)

    changeset =
      Automations.change_automation(socket.assigns.automation, params)

    {:noreply,
     socket
     |> assign(:selected_type, selected_type)
     |> assign(form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"automation" => automation_params}, socket) do
    save_automation(socket, socket.assigns.action, automation_params)
  end

  defp save_automation(socket, :edit, automation_params) do
    selected_type = parse_type(automation_params["type"])

    params =
      automation_params
      |> Map.put("user_id", socket.assigns.current_user.id)
      |> maybe_set_update_contact_fields(selected_type)

    case Automations.update_automation(socket.assigns.automation, params) do
      {:ok, automation} ->
        notify_parent({:saved, automation})

        {:noreply,
         socket
         |> put_flash(:info, "Automation updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_automation(socket, :new, automation_params) do
    selected_type = parse_type(automation_params["type"])

    params =
      automation_params
      |> Map.put("user_id", socket.assigns.current_user.id)
      |> maybe_set_update_contact_fields(selected_type)

    case Automations.create_automation(params) do
      {:ok, automation} ->
        notify_parent({:saved, automation})

        {:noreply,
         socket
         |> put_flash(:info, "Automation created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  defp maybe_set_update_contact_fields(params, :update_contact) do
    params
    |> Map.put("description", Automations.update_contact_description())
    |> Map.put("example", Automations.update_contact_example())
  end

  defp maybe_set_update_contact_fields(params, _type), do: params

  defp parse_type("content_generation"), do: :content_generation
  defp parse_type("update_contact"), do: :update_contact
  defp parse_type(_), do: nil

  defp type_options do
    [
      {"Content Generation", :content_generation},
      {"Update Contact", :update_contact}
    ]
  end

  defp platform_options_for_type(:update_contact), do: [{:hubspot, :hubspot}]

  defp platform_options_for_type(_type) do
    Automation.platform_values()
    |> Enum.reject(&(&1 == :hubspot))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
