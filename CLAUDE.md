# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Social Scribe is an Elixir/Phoenix LiveView application that automates meeting transcription and social media content generation. The app connects to Google Calendar, sends Recall.ai bots to meetings, transcribes them, and uses Google Gemini to generate follow-up emails and platform-specific social media posts.

## Common Commands

### Development Setup
```bash
# Install dependencies and setup database
mix setup

# Start Phoenix server
mix phx.server

# Start Phoenix server with IEx console
iex -S mix phx.server
```

### Database Operations
```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate

# Reset database (drop, create, migrate, seed)
mix ecto.reset

# Rollback last migration
mix ecto.rollback

# Run seed file
mix run priv/repo/seeds.exs
```

### Testing
```bash
# Run all tests
mix test

# Run specific test file
mix test test/path/to/test_file.exs

# Run tests with line number
mix test test/path/to/test_file.exs:42
```

### Code Quality
```bash
# Format code
mix format

# Check for compilation warnings (CI mode)
mix compile --warnings-as-errors
```

### Asset Management
```bash
# Install asset dependencies
mix assets.setup

# Build assets for development
mix assets.build

# Build and minify assets for production
mix assets.deploy
```

### Background Jobs (Oban)
Access the Oban dashboard at `http://localhost:4000/oban` (development only) to monitor background jobs.

## Architecture

### Core Domain Contexts

The application follows Phoenix contexts pattern with these main domains:

- **Accounts** (`lib/social_scribe/accounts.ex`): User management and multi-provider OAuth credentials (Google, LinkedIn, Facebook)
- **Meetings** (`lib/social_scribe/meetings.ex`): Meeting records, transcripts, and participants from Recall.ai
- **Automations** (`lib/social_scribe/automations.ex`): User-defined content generation templates and their results
- **Bots** (`lib/social_scribe/bots.ex`): Recall.ai bot management and user preferences

### Background Job Processing

Oban handles all asynchronous operations with three queues (`config/config.exs`):
- `default`: General background tasks (10 workers)
- `ai_content`: AI content generation (10 workers)
- `polling`: Recall.ai bot status polling (5 workers)

#### Key Workers

1. **BotStatusPoller** (`lib/social_scribe/workers/bot_status_poller.ex`)
   - Runs every 2 minutes via cron
   - Polls pending Recall.ai bots for status updates
   - When bot status is "done", fetches transcript and creates Meeting record
   - Automatically enqueues AIContentGenerationWorker for completed meetings

2. **AIContentGenerationWorker** (`lib/social_scribe/workers/ai_content_generation_worker.ex`)
   - Generates follow-up email using Google Gemini
   - Processes all active user automations to generate platform-specific content
   - Stores results as AutomationResult records

### External API Integrations

All API clients are in `lib/social_scribe/*_api.ex`:

- **RecallApi**: Recall.ai bot management (create bots, poll status, fetch transcripts)
- **GoogleCalendarApi**: Fetch calendar events and sync with database
- **AIContentGeneratorApi**: Google Gemini integration for content generation
- **LinkedInApi**: Post content to LinkedIn profiles
- **FacebookApi**: Post content to Facebook Pages
- **TokenRefresherApi**: Refresh OAuth tokens as needed

### Authentication Flow

Multi-provider OAuth via Ueberauth:
- Users can connect multiple Google accounts for calendar aggregation
- LinkedIn and Facebook connections are stored as UserCredentials
- Facebook requires Page selection (stored in FacebookPageCredential)
- All OAuth flows handled in `lib/social_scribe_web/controllers/auth_controller.ex`
- Routes: `/auth/:provider` and `/auth/:provider/callback`

### LiveView Pages

Main user-facing pages in `lib/social_scribe_web/live/`:

- **LandingLive**: Public landing page
- **HomeLive**: Dashboard showing upcoming calendar events with "Record Meeting?" toggles
- **UserSettingsLive**: Connect/disconnect Google, LinkedIn, Facebook accounts; select Facebook Page
- **MeetingLive.Index**: List of processed meetings
- **MeetingLive.Show**: Meeting details with transcript, follow-up email, and automation results
- **AutomationLive.Index**: Create and manage automation templates
- **AutomationLive.Show**: View individual automation details

All authenticated pages use the `:dashboard` layout with sidebar navigation.

### Data Flow: Meeting Recording to Content Generation

1. User enables "Record Meeting?" toggle on dashboard (HomeLive)
2. System creates UserBotPreference and RecallBot record
3. Recall.ai bot joins meeting at scheduled time
4. BotStatusPoller (cron job every 2 minutes) checks bot status
5. When bot status = "done", poller fetches transcript and creates Meeting + MeetingTranscript + MeetingParticipants
6. AIContentGenerationWorker is enqueued automatically
7. Worker generates follow-up email and processes all active user automations
8. Generated content stored in Meeting.follow_up_email and AutomationResults
9. User views content on MeetingLive.Show page, can copy or post directly to social platforms

### Prompt Generation

Meeting context for AI generation is built in `Meetings.generate_prompt_for_meeting/1`:
- Combines meeting title, date, duration
- Formats participant list with roles (Host/Participant)
- Converts transcript segments into "Speaker: Text" format

Automation prompts combine the meeting context with user-defined templates in `Automations.generate_prompt_for_automation/1`.

## Important Constraints

### Recall.ai Bot Management
- Must track individual `bot_id`s (cannot use general `/bots` endpoint per challenge rules)
- Polling is required as webhooks are not available with shared API key
- Bot status polling happens via cron job, not per-bot scheduling

### Calendar Sync Limitation
Currently only syncs calendar events that have:
- A `hangoutLink` field (Google Meet), OR
- A `location` field containing Zoom or Google Meet URL

### Facebook Posting
- Requires Meta app review for production use beyond app administrators/developers/testers
- During development, posting works for app admins to Pages they manage
- Users must select a specific Page after Facebook OAuth (handled in UserSettingsLive)

### Automation Limits
- Users can have only **one active automation per platform** (enforced in Automations context)
- Validation occurs in both `create_automation/1` and `update_automation/2`

## Environment Variables

Required environment variables (configure in `.env` or runtime):
- `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI`
- `RECALL_API_KEY`
- `GEMINI_API_KEY`
- `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET`, `LINKEDIN_REDIRECT_URI`
- `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET`, `FACEBOOK_REDIRECT_URI`

Configuration loaded in `config/runtime.exs`.

## Testing Conventions

Test files mirror source structure in `test/`:
- Context tests: `test/social_scribe/context_test.exs`
- LiveView tests: `test/social_scribe_web/live/page_live_test.exs`
- Use `SocialScribe.DataCase` for database tests
- Use `SocialScribeWeb.ConnCase` for controller/LiveView tests

## Phoenix Framework Conventions

- Contexts expose public APIs (list, get, create, update, delete functions)
- LiveView components use `~H` sigil for HEEx templates
- PubSub used for real-time updates (SocialScribe.PubSub)
- Ecto changesets for data validation
- Preload associations explicitly before accessing (avoid N+1 queries)

## CI/CD

GitHub Actions workflow (`.github/workflows/ci-cd.yml`):
- Runs tests, compilation checks with warnings-as-errors, format checks
- Deploys to Fly.io on successful push to `main` branch
- Requires `FLY_API_TOKEN` secret in repository settings
