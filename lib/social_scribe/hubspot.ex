defmodule SocialScribe.HubSpot do
  @moduledoc """
  Implementation of the HubSpot API client.
  """

  require Logger

  @behaviour SocialScribe.HubSpotApi

  @hubspot_api_base_url "https://api.hubapi.com"

  @contact_properties "firstname,lastname,email,phone,address,date_of_birth,company"

  defp client(access_token) do
    middleware = [
      {Tesla.Middleware.BaseUrl, @hubspot_api_base_url},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Bearer #{access_token}"},
         {"Content-Type", "application/json"}
       ]}
    ]

    adapter = Application.get_env(:tesla, :adapter)
    Tesla.client(middleware, adapter)
  end

  @impl SocialScribe.HubSpotApi
  def list_contacts(access_token, search_query \\ nil)

  def list_contacts(access_token, nil) do
    url = "/crm/v3/objects/contacts"

    params = [properties: @contact_properties]

    case Tesla.get(client(access_token), url, query: params) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        contacts =
          body
          |> Map.get("results", [])
          |> Enum.map(&parse_contact/1)

        {:ok, contacts}

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        Logger.error("HubSpot API Error (Status: #{status}): #{inspect(error_body)}")
        {:error, {:api_error, status, error_body}}

      {:error, reason} ->
        Logger.error("HubSpot HTTP Error: #{inspect(reason)}")
        {:error, {:http_error, reason}}
    end
  end

  def list_contacts(access_token, search_query) when is_binary(search_query) do
    url = "/crm/v3/objects/contacts/search"

    payload = %{
      filterGroups: [
        %{
          filters: [
            %{
              propertyName: "firstname",
              operator: "CONTAINS_TOKEN",
              value: search_query
            }
          ]
        },
        %{
          filters: [
            %{
              propertyName: "lastname",
              operator: "CONTAINS_TOKEN",
              value: search_query
            }
          ]
        },
        %{
          filters: [
            %{
              propertyName: "email",
              operator: "CONTAINS_TOKEN",
              value: search_query
            }
          ]
        }
      ],
      properties: String.split(@contact_properties, ","),
      limit: 10
    }

    case Tesla.post(client(access_token), url, payload) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        contacts =
          body
          |> Map.get("results", [])
          |> Enum.map(&parse_contact/1)

        {:ok, contacts}

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        Logger.error("HubSpot API Error (Status: #{status}): #{inspect(error_body)}")
        {:error, {:api_error, status, error_body}}

      {:error, reason} ->
        Logger.error("HubSpot HTTP Error: #{inspect(reason)}")
        {:error, {:http_error, reason}}
    end
  end

  @impl SocialScribe.HubSpotApi
  def get_contact(access_token, contact_id) do
    url = "/crm/v3/objects/contacts/#{contact_id}"

    params = [properties: @contact_properties]

    case Tesla.get(client(access_token), url, query: params) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, parse_contact(body)}

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        Logger.error("HubSpot API Error (Status: #{status}): #{inspect(error_body)}")
        {:error, {:api_error, status, error_body}}

      {:error, reason} ->
        Logger.error("HubSpot HTTP Error: #{inspect(reason)}")
        {:error, {:http_error, reason}}
    end
  end

  @impl SocialScribe.HubSpotApi
  def update_contact(access_token, contact_id, properties) do
    url = "/crm/v3/objects/contacts/#{contact_id}"

    payload = %{properties: properties}

    case Tesla.patch(client(access_token), url, payload) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, parse_contact(body)}

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        Logger.error("HubSpot API Error (Status: #{status}): #{inspect(error_body)}")
        {:error, {:api_error, status, error_body}}

      {:error, reason} ->
        Logger.error("HubSpot HTTP Error: #{inspect(reason)}")
        {:error, {:http_error, reason}}
    end
  end

  defp parse_contact(contact_data) do
    # Handle both nested properties format and flat format
    properties = Map.get(contact_data, "properties", contact_data)

    %{
      id: Map.get(contact_data, "id"),
      firstname: Map.get(properties, "firstname"),
      lastname: Map.get(properties, "lastname"),
      email: Map.get(properties, "email"),
      phone: Map.get(properties, "phone"),
      address: Map.get(properties, "address"),
      date_of_birth: Map.get(properties, "date_of_birth"),
      company: Map.get(properties, "company")
    }
  end
end
