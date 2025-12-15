defmodule SocialScribe.AutomationsTest do
  use SocialScribe.DataCase

  alias SocialScribe.Automations
  alias SocialScribe.Automations.{Automation, AutomationResult}

  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures
  import SocialScribe.CalendarFixtures

  import SocialScribe.AutomationsFixtures

  describe "automations" do
    @invalid_attrs %{
      name: nil,
      description: nil,
      platform: nil,
      example: nil,
      is_active: nil
    }

    test "list_active_user_automations/1 returns the list of active automations for a user" do
      user = user_fixture()
      _automation_3 = automation_fixture(%{user_id: user.id, is_active: false})
      automation_1 = automation_fixture(%{user_id: user.id, is_active: true, platform: :linkedin})
      automation_2 = automation_fixture(%{user_id: user.id, is_active: true, platform: :facebook})
      _automation_4 = automation_fixture(%{is_active: true})

      assert Automations.list_active_user_automations(user.id) == [automation_1, automation_2]
    end

    test "list_active_user_automations_by_type/2 returns active automations filtered by type" do
      user = user_fixture()

      content_automation =
        automation_fixture(%{
          user_id: user.id,
          is_active: true,
          type: :content_generation,
          platform: :linkedin
        })

      _update_contact_automation =
        automation_fixture(%{
          user_id: user.id,
          is_active: true,
          type: :update_contact,
          platform: :hubspot
        })

      assert Automations.list_active_user_automations_by_type(user.id, :content_generation) == [
               content_automation
             ]
    end

    test "list_active_user_automations_by_type/2 returns update_contact automations for HubSpot" do
      user = user_fixture()

      _content_automation =
        automation_fixture(%{
          user_id: user.id,
          is_active: true,
          type: :content_generation,
          platform: :linkedin
        })

      update_contact_automation =
        automation_fixture(%{
          user_id: user.id,
          is_active: true,
          type: :update_contact,
          platform: :hubspot
        })

      assert Automations.list_active_user_automations_by_type(user.id, :update_contact) == [
               update_contact_automation
             ]
    end

    test "list_automations/0 returns all automations" do
      automation = automation_fixture()
      assert Automations.list_automations() == [automation]
    end

    test "get_automation!/1 returns the automation with given id" do
      automation = automation_fixture()
      assert Automations.get_automation!(automation.id) == automation
    end

    test "can_create_automation?/2 returns true if the user has no active automations for the given platform" do
      user = user_fixture()
      assert Automations.can_create_automation?(user.id, :linkedin) == true
    end

    test "can_create_automation?/2 returns false if the user has an active automation for the given platform" do
      user = user_fixture()
      _automation = automation_fixture(%{user_id: user.id, platform: :linkedin, is_active: true})
      assert Automations.can_create_automation?(user.id, :linkedin) == false
    end

    test "create_automation/1 with valid data creates a automation" do
      user = user_fixture()

      valid_attrs = %{
        name: "some name",
        type: :content_generation,
        description: "some description",
        platform: :linkedin,
        example: "some example",
        is_active: true,
        user_id: user.id
      }

      assert {:ok, %Automation{} = automation} = Automations.create_automation(valid_attrs)
      assert automation.name == "some name"
      assert automation.type == :content_generation
      assert automation.description == "some description"
      assert automation.platform == :linkedin
      assert automation.example == "some example"
      assert automation.is_active == true
    end

    test "create_automation/1 with update_contact type creates a HubSpot automation" do
      user = user_fixture()

      valid_attrs = %{
        name: "Update HubSpot Contact",
        type: :update_contact,
        description: Automations.update_contact_description(),
        platform: :hubspot,
        example: Automations.update_contact_example(),
        is_active: true,
        user_id: user.id
      }

      assert {:ok, %Automation{} = automation} = Automations.create_automation(valid_attrs)
      assert automation.name == "Update HubSpot Contact"
      assert automation.type == :update_contact
      assert automation.platform == :hubspot
      assert automation.is_active == true
    end

    test "create_automation/1 with update_contact type requires hubspot platform" do
      user = user_fixture()

      invalid_attrs = %{
        name: "Invalid Update Contact",
        type: :update_contact,
        description: "some description",
        platform: :linkedin,
        example: "some example",
        is_active: true,
        user_id: user.id
      }

      assert {:error, %Ecto.Changeset{} = changeset} =
               Automations.create_automation(invalid_attrs)

      assert "must be hubspot for update_contact automations" in errors_on(changeset).platform
    end

    test "create_automation/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Automations.create_automation(@invalid_attrs)
    end

    test "update_automation/2 with valid data updates the automation" do
      automation = automation_fixture()

      update_attrs = %{
        name: "some updated name",
        description: "some updated description",
        platform: :facebook,
        example: "some updated example",
        is_active: false
      }

      assert {:ok, %Automation{} = automation} =
               Automations.update_automation(automation, update_attrs)

      assert automation.name == "some updated name"
      assert automation.description == "some updated description"
      assert automation.platform == :facebook
      assert automation.example == "some updated example"
      assert automation.is_active == false
    end

    test "update_automation/2 respects limit of one active automation per platform per user" do
      user = user_fixture()
      automation_1 = automation_fixture(%{user_id: user.id, platform: :linkedin, is_active: true})

      _automation_2 =
        automation_fixture(%{user_id: user.id, platform: :facebook, is_active: true})

      assert {:error, %Ecto.Changeset{}} =
               Automations.update_automation(automation_1, %{platform: :facebook})
    end

    test "update_automation/2 with invalid data returns error changeset" do
      automation = automation_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Automations.update_automation(automation, @invalid_attrs)

      assert automation == Automations.get_automation!(automation.id)
    end

    test "delete_automation/1 deletes the automation" do
      automation = automation_fixture()
      assert {:ok, %Automation{}} = Automations.delete_automation(automation)
      assert_raise Ecto.NoResultsError, fn -> Automations.get_automation!(automation.id) end
    end

    test "change_automation/1 returns a automation changeset" do
      automation = automation_fixture()
      assert %Ecto.Changeset{} = Automations.change_automation(automation)
    end

    test "generates a prompt for an automation" do
      automation = automation_fixture()

      assert Automations.generate_prompt_for_automation(automation) =~
               """
               #{automation.description}

               ### Example:
               #{automation.example}
               """
    end

    test "generates a prompt for update_contact automation using predefined description and example" do
      user = user_fixture()

      automation =
        automation_fixture(%{
          user_id: user.id,
          type: :update_contact,
          platform: :hubspot
        })

      prompt = Automations.generate_prompt_for_automation(automation)

      assert prompt =~ Automations.update_contact_description()
      assert prompt =~ Automations.update_contact_example()
    end

    test "update_contact_description/0 returns the predefined description" do
      description = Automations.update_contact_description()
      assert description =~ "Analyze the meeting transcript"
      assert description =~ "field_id: firstname"
      assert description =~ "Return ONLY a valid JSON array"
    end

    test "update_contact_example/0 returns the predefined example" do
      example = Automations.update_contact_example()
      assert example =~ "field_id"
      assert example =~ "field_name"
      assert example =~ "suggested_value"
      assert example =~ "transcript_timestamp"
    end
  end

  describe "automation_results" do
    @invalid_attrs %{status: nil, generated_content: nil, error_message: nil}

    test "list_automation_results/0 returns all automation_results" do
      automation_result = automation_result_fixture()
      assert Automations.list_automation_results() == [automation_result]
    end

    test "list_automation_results_for_meeting/1 returns the list of automation_results for a meeting" do
      automation_result = automation_result_fixture()

      assert Automations.list_automation_results_for_meeting(automation_result.meeting_id) == [
               Repo.preload(automation_result, [:automation])
             ]
    end

    test "list_automation_results_for_meeting_by_type/2 returns results filtered by automation type" do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})
      meeting = meeting_fixture(%{calendar_event_id: calendar_event.id})

      content_automation =
        automation_fixture(%{
          user_id: user.id,
          type: :content_generation,
          platform: :linkedin
        })

      update_contact_automation =
        automation_fixture(%{
          user_id: user.id,
          type: :update_contact,
          platform: :hubspot
        })

      _content_result =
        automation_result_fixture(%{
          automation_id: content_automation.id,
          meeting_id: meeting.id
        })

      update_contact_result =
        automation_result_fixture(%{
          automation_id: update_contact_automation.id,
          meeting_id: meeting.id
        })

      results = Automations.list_automation_results_for_meeting_by_type(meeting.id, :update_contact)

      assert length(results) == 1
      assert List.first(results).id == update_contact_result.id
      assert List.first(results).automation.type == :update_contact
    end

    test "get_automation_result!/1 returns the automation_result with given id" do
      automation_result = automation_result_fixture()
      assert Automations.get_automation_result!(automation_result.id) == automation_result
    end

    test "create_automation_result/1 with valid data creates a automation_result" do
      user = user_fixture()
      automation = automation_fixture(%{user_id: user.id})
      calendar_event = calendar_event_fixture(%{user_id: user.id})
      meeting = meeting_fixture(%{calendar_event_id: calendar_event.id})

      valid_attrs = %{
        automation_id: automation.id,
        meeting_id: meeting.id,
        status: "some status",
        generated_content: "some generated_content"
      }

      assert {:ok, %AutomationResult{} = automation_result} =
               Automations.create_automation_result(valid_attrs)

      assert automation_result.status == "some status"
      assert automation_result.generated_content == "some generated_content"
    end

    test "create_automation_result/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Automations.create_automation_result(@invalid_attrs)
    end

    test "update_automation_result/2 with valid data updates the automation_result" do
      automation_result = automation_result_fixture()

      update_attrs = %{
        status: "some updated status",
        generated_content: "some updated generated_content",
        error_message: "some updated error_message"
      }

      assert {:ok, %AutomationResult{} = automation_result} =
               Automations.update_automation_result(automation_result, update_attrs)

      assert automation_result.status == "some updated status"
      assert automation_result.generated_content == "some updated generated_content"
      assert automation_result.error_message == "some updated error_message"
    end

    test "update_automation_result/2 with invalid data returns error changeset" do
      automation_result = automation_result_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Automations.update_automation_result(automation_result, @invalid_attrs)

      assert automation_result == Automations.get_automation_result!(automation_result.id)
    end

    test "delete_automation_result/1 deletes the automation_result" do
      automation_result = automation_result_fixture()
      assert {:ok, %AutomationResult{}} = Automations.delete_automation_result(automation_result)

      assert_raise Ecto.NoResultsError, fn ->
        Automations.get_automation_result!(automation_result.id)
      end
    end

    test "change_automation_result/1 returns a automation_result changeset" do
      automation_result = automation_result_fixture()
      assert %Ecto.Changeset{} = Automations.change_automation_result(automation_result)
    end
  end
end
