defmodule SocialScribe.Automations.Automation do
  use Ecto.Schema
  import Ecto.Changeset

  @type_values [:content_generation, :update_contact]
  @platform_values [:linkedin, :facebook, :hubspot]

  schema "automations" do
    field :name, :string
    field :type, Ecto.Enum, values: @type_values
    field :description, :string
    field :platform, Ecto.Enum, values: @platform_values
    field :example, :string
    field :is_active, :boolean, default: true

    belongs_to :user, SocialScribe.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def type_values, do: @type_values
  def platform_values, do: @platform_values

  @doc false
  def changeset(automation, attrs) do
    automation
    |> cast(attrs, [:name, :type, :platform, :description, :example, :is_active, :user_id])
    |> validate_required([:name, :type, :platform, :is_active, :user_id])
    |> validate_type_platform_combination()
    |> validate_content_generation_fields()
  end

  defp validate_type_platform_combination(changeset) do
    type = get_field(changeset, :type)
    platform = get_field(changeset, :platform)

    cond do
      type == :update_contact && platform != :hubspot ->
        add_error(changeset, :platform, "must be hubspot for update_contact automations")

      type == :content_generation && platform == :hubspot ->
        add_error(changeset, :platform, "hubspot is not available for content_generation automations")

      true ->
        changeset
    end
  end

  defp validate_content_generation_fields(changeset) do
    type = get_field(changeset, :type)

    if type == :content_generation do
      changeset
      |> validate_required([:description, :example])
    else
      changeset
    end
  end
end
