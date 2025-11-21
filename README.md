# CommCare Utils

A Rails application for syncing data from CommCare HQ to external PostgreSQL databases. This tool enables automated data forwarding and scheduled syncing of CommCare case data to destination databases with support for sensitive field hashing and custom table mappings.

## Overview

CommCare Utils acts as a bridge between CommCare HQ and external databases, providing:
- **Real-time data forwarding** via webhooks from CommCare
- **Scheduled batch syncing** of case data from CommCare export tables
- **Sensitive field protection** through one-way hashing
- **Dynamic schema management** with automatic table and column creation
- **Token-based API authentication** for secure webhook endpoints

## Getting Started

### Prerequisites

- Ruby 3.4.3
- PostgreSQL
- CommCare HQ account with API access

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd commcare-utils
```

2. Install dependencies:
```bash
bundle install
```

3. Set up the database:
```bash
bin/rails db:create
bin/rails db:migrate
```

4. Configure environment variables (create a `.env` file), see `.env.example` for required variables

### Running Locally

For local development, use `Procfile.dev` which includes the web server, CSS compiler, and background worker:

```bash
bin/dev
```

This starts:
- **web**: Puma web server on port 3000
- **css**: DartSass CSS compiler in watch mode
- **worker**: GoodJob background worker for processing async jobs

### Deployment

The application is configured for Heroku deployment using the `Procfile`:

```bash
git push heroku main
```

The `Procfile` includes:
- **web**: Puma web server
- **worker**: GoodJob background worker
- **release**: Automatic database migrations on deploy

## Data Models

### Destination

Represents a target database and CommCare project configuration.

**Key attributes:**
- `name` - Friendly name for the destination
- `project_name` - CommCare project name
- `database_url` - PostgreSQL connection string (encrypted)
- `commcare_username` - CommCare API username
- `commcare_password` - CommCare API key (encrypted)

**Relationships:**
- `has_many :destination_sources` - Data sources to sync
- `has_many :destination_tokens` - API tokens for webhook authentication

**Methods:**
- `handle_forwarded_case(case_id)` - Process a forwarded case from CommCare webhook
- `commcare_client` - Returns configured CommCare API client

### DestinationSource

Represents a specific case type or data export from CommCare that should be synced to a table.

**Key attributes:**
- `name` - Friendly name for the source
- `case_type` - CommCare case type (for case-based syncing)
- `url` - CommCare export URL for table-based syncing
- `table_name` - Target table name in destination database
- `key_column` - Primary key column for upserts
- `sensitive_fields` - Comma-separated list of fields to hash
- `scheduled_sync` - Enable/disable scheduled batch syncing

**Relationships:**
- `belongs_to :destination`

**Methods:**
- `sync_source` - Sync data from CommCare export URL to destination table
- `sync_case(case_data, owner, opened_by_user, closed_by_user)` - Sync a single case with metadata

**Includes:**
- `TableWritable` concern - Provides database writing and table management functionality

### DestinationToken

API tokens for authenticating webhook requests from CommCare.

**Key attributes:**
- `token` - UUID token (auto-generated)
- `last_accessed_at` - Timestamp of last use

**Relationships:**
- `belongs_to :destination`

**Methods:**
- `self.authenticate(token_string)` - Validate and return token
- `touch_last_accessed` - Update last access timestamp (rate-limited to 1 minute)

### User

Application users authenticated via passwordless email login.

**Key attributes:**
- `email` - User email address (unique)

**Authentication:**
Uses the `passwordless` gem for magic link email authentication.

## Background Jobs

### SyncSourceJob

Syncs a single `DestinationSource` from CommCare to the destination database.

**Usage:**
```ruby
SyncSourceJob.perform_later(destination_source_id)
```

### SyncAllSourcesJob

Queues sync jobs for all `DestinationSource` records with `scheduled_sync: true`.

**Usage:**
```ruby
SyncAllSourcesJob.perform_later
```

Can be scheduled via cron or GoodJob's built-in scheduler.

### DataForwardJob

Processes real-time case data forwarded from CommCare webhooks.

**Usage:**
```ruby
DataForwardJob.perform_later(destination_token_id, payload)
```

Supports both XML and JSON payload formats from CommCare.

## Core Components

### TableWritable (Concern)

Provides database table management and data syncing functionality for `DestinationSource`.

**Key features:**
- Dynamic table and column creation
- Type inference and coercion
- Upsert operations with conflict resolution
- Sensitive field hashing (SHA256, truncated to 15 chars)
- Automatic cleanup of stale records
- Streaming HTML table parsing from CommCare exports

**Methods:**
- `ensure_table(columns, drop_columns)` - Create/update table schema
- `upsert_row(columns, values, time)` - Insert or update a row
- `delete_rows_updated_before(time)` - Remove stale records
- `parse_source(&block)` - Stream and parse CommCare export HTML

### DatabaseWriter

Low-level PostgreSQL database operations for destination databases.

**Features:**
- Direct PostgreSQL connection management
- Table and column DDL operations
- Type mapping and conversion
- Parameterized queries for safety

**Type mapping:**
- `string` → `text`
- `integer` → `integer`
- `float` → `decimal`
- `datetime` → `timestamp without time zone`

### CommcareClient

HTTP client for CommCare HQ API.

**Methods:**
- `get_case(case_id)` - Fetch case data
- `get_user(user_id)` - Fetch user data
- `get_location(location_id)` - Fetch location data

## Architecture

### Data Flow

1. **Webhook Flow** (Real-time):
   - CommCare sends case update → Webhook endpoint
   - Validates `DestinationToken`
   - Queues `DataForwardJob`
   - Job fetches full case data via API
   - Syncs to destination database via `sync_case`

2. **Scheduled Sync Flow** (Batch):
   - `SyncAllSourcesJob` runs on schedule
   - Queues `SyncSourceJob` for each enabled source
   - Job streams HTML export from CommCare
   - Parses and upserts rows to destination database
   - Removes stale records

### Security Features

- Encrypted credentials (database URLs, CommCare passwords)
- Token-based webhook authentication
- Sensitive field hashing (one-way SHA256)
- Parameterized SQL queries
- HTTP success validation before parsing

## Tech Stack

- **Framework**: Rails 8.1
- **Ruby**: 3.4.3
- **Database**: PostgreSQL
- **Job Queue**: GoodJob (database-backed)
- **Authentication**: Passwordless (magic link email)
- **Frontend**: Hotwire (Turbo + Stimulus), Bootstrap 5
- **CSS**: DartSass
- **Deployment**: Heroku, Kamal (Docker)

