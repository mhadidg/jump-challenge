defmodule SocialScribe.HubSpotApi do
  @moduledoc """
  Behaviour for HubSpot API operations.
  """

  @callback list_contacts(access_token :: String.t(), search_query :: String.t() | nil) ::
              {:ok, list(map())} | {:error, term()}

  @callback get_contact(access_token :: String.t(), contact_id :: String.t()) ::
              {:ok, map()} | {:error, term()}

  @callback update_contact(
              access_token :: String.t(),
              contact_id :: String.t(),
              properties :: map()
            ) ::
              {:ok, map()} | {:error, term()}

  def list_contacts(access_token, search_query \\ nil),
    do: impl().list_contacts(access_token, search_query)

  def get_contact(access_token, contact_id),
    do: impl().get_contact(access_token, contact_id)

  def update_contact(access_token, contact_id, properties),
    do: impl().update_contact(access_token, contact_id, properties)

  defp impl, do: Application.get_env(:social_scribe, :hubspot_api, SocialScribe.HubSpot)
end
