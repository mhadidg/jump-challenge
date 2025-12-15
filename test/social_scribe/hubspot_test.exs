defmodule SocialScribe.HubSpotTest do
  use SocialScribe.DataCase, async: true

  alias SocialScribe.HubSpot

  import Tesla.Mock

  @access_token "test-access-token"

  setup do
    mock(fn
      %{method: :get, url: "https://api.hubapi.com/crm/v3/objects/contacts"} ->
        json(%{
          "results" => [
            %{
              "id" => "123",
              "firstname" => "John",
              "lastname" => "Doe",
              "email" => "john@example.com",
              "phone" => "555-1234",
              "address" => "123 Main St",
              "date_of_birth" => "1990-01-01",
              "company" => "Acme Inc"
            }
          ]
        })

      %{method: :post, url: "https://api.hubapi.com/crm/v3/objects/contacts/search"} ->
        json(%{
          "results" => [
            %{
              "id" => "456",
              "properties" => %{
                "firstname" => "Jane",
                "lastname" => "Smith",
                "email" => "jane@example.com",
                "phone" => nil,
                "address" => nil,
                "date_of_birth" => nil,
                "company" => nil
              }
            }
          ]
        })

      %{method: :get, url: "https://api.hubapi.com/crm/v3/objects/contacts/123"} ->
        json(%{
          "id" => "123",
          "firstname" => "John",
          "lastname" => "Doe",
          "email" => "john@example.com",
          "phone" => "555-1234",
          "address" => "123 Main St",
          "date_of_birth" => "1990-01-01",
          "company" => "Acme Inc"
        })

      %{method: :patch, url: "https://api.hubapi.com/crm/v3/objects/contacts/123"} ->
        json(%{
          "id" => "123",
          "properties" => %{
            "firstname" => "Johnny",
            "lastname" => "Doe",
            "email" => "john@example.com",
            "phone" => "555-1234",
            "address" => "123 Main St",
            "date_of_birth" => "1990-01-01",
            "company" => "Acme Inc"
          }
        })
    end)

    :ok
  end

  describe "list_contacts/2" do
    test "returns contacts without search query" do
      assert {:ok, contacts} = HubSpot.list_contacts(@access_token)

      assert [contact] = contacts
      assert contact.id == "123"
      assert contact.firstname == "John"
      assert contact.lastname == "Doe"
      assert contact.email == "john@example.com"
    end

    test "returns contacts with search query" do
      assert {:ok, contacts} = HubSpot.list_contacts(@access_token, "Jane")

      assert [contact] = contacts
      assert contact.id == "456"
      assert contact.firstname == "Jane"
      assert contact.lastname == "Smith"
    end
  end

  describe "get_contact/2" do
    test "returns a single contact by id" do
      assert {:ok, contact} = HubSpot.get_contact(@access_token, "123")

      assert contact.id == "123"
      assert contact.firstname == "John"
      assert contact.lastname == "Doe"
      assert contact.email == "john@example.com"
    end
  end

  describe "update_contact/3" do
    test "updates a contact and returns the updated contact" do
      properties = %{firstname: "Johnny"}

      assert {:ok, contact} = HubSpot.update_contact(@access_token, "123", properties)

      assert contact.id == "123"
      assert contact.firstname == "Johnny"
    end
  end
end
