defmodule SocialScribeWeb.MeetingLiveTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures
  import SocialScribe.CalendarFixtures
  import SocialScribe.BotsFixtures
  import SocialScribe.AutomationsFixtures

  describe "Show" do
    setup %{conn: conn} do
      user = user_fixture()
      calendar_event = calendar_event_fixture(%{user_id: user.id})
      recall_bot = recall_bot_fixture(%{calendar_event_id: calendar_event.id, user_id: user.id})

      meeting =
        meeting_fixture(%{
          calendar_event_id: calendar_event.id,
          recall_bot_id: recall_bot.id,
          title: "Test Meeting"
        })

      %{conn: log_in_user(conn, user), user: user, meeting: meeting}
    end

    test "displays meeting details", %{conn: conn, meeting: meeting} do
      {:ok, _show_live, html} = live(conn, ~p"/dashboard/meetings/#{meeting}")

      assert html =~ "Meeting Details"
      assert html =~ meeting.title
    end

    test "displays message when user has no content automations", %{conn: conn, meeting: meeting} do
      {:ok, _show_live, html} = live(conn, ~p"/dashboard/meetings/#{meeting}")

      assert html =~ "You do not have any active content generation automations."
    end

    test "displays message when user has no contact update automations", %{
      conn: conn,
      meeting: meeting
    } do
      {:ok, _show_live, html} = live(conn, ~p"/dashboard/meetings/#{meeting}")

      assert html =~ "You do not have any active contact update automations."
    end

    test "displays content automation results when available", %{
      conn: conn,
      user: user,
      meeting: meeting
    } do
      content_automation =
        automation_fixture(%{
          user_id: user.id,
          type: :content_generation,
          platform: :linkedin,
          name: "LinkedIn Post Generator"
        })

      automation_result_fixture(%{
        automation_id: content_automation.id,
        meeting_id: meeting.id,
        generated_content: "Generated LinkedIn post content"
      })

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/meetings/#{meeting}")

      assert html =~ "LinkedIn Post Generator"
      assert html =~ "View"
    end

    test "displays contact update automation results when available", %{
      conn: conn,
      user: user,
      meeting: meeting
    } do
      contact_automation =
        automation_fixture(%{
          user_id: user.id,
          type: :update_contact,
          platform: :hubspot,
          name: "HubSpot Contact Sync"
        })

      automation_result_fixture(%{
        automation_id: contact_automation.id,
        meeting_id: meeting.id,
        generated_content: ~s|[{"field_id": "firstname", "suggested_value": "John"}]|
      })

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/meetings/#{meeting}")

      assert html =~ "HubSpot Contact Sync"
      assert html =~ "View Changes"
    end

    test "displays pending message when user has contact automations but no results", %{
      conn: conn,
      user: user,
      meeting: meeting
    } do
      _contact_automation =
        automation_fixture(%{
          user_id: user.id,
          type: :update_contact,
          platform: :hubspot,
          name: "HubSpot Contact Sync"
        })

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/meetings/#{meeting}")

      assert html =~ "No contact updates extracted for this meeting yet"
    end
  end
end
