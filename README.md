# CommCare Utils

A Rails application that copies data out of [CommCare HQ](https://www.commcarehq.org) into external PostgreSQL databases. It supports two ways of getting data across:

- **Data forwarding (near real-time).** CommCare HQ posts each case update or form submission to this app's webhook. The app fetches any extra detail it needs from the CommCare API and upserts a row into the destination database.
- **Scheduled export sync (daily batch).** The app downloads a CommCare "Excel Dashboard Integration" export feed once a day, and replaces the contents of a destination table with it.

Destination tables and columns are created and extended automatically. Selected fields can be one-way hashed before they are written.

## Contents

- [Concepts](#concepts)
- [How to use](#how-to-use)
  - [1. Sign in and manage users](#1-sign-in-and-manage-users)
  - [2. Create a destination](#2-create-a-destination)
  - [3. Forward cases](#3-forward-cases)
  - [4. Forward forms](#4-forward-forms)
  - [5. Sync an export feed on a schedule](#5-sync-an-export-feed-on-a-schedule)
  - [6. Sensitive fields](#6-sensitive-fields)
  - [7. Monitoring jobs and troubleshooting](#7-monitoring-jobs-and-troubleshooting)
- [What gets written to the destination database](#what-gets-written-to-the-destination-database)
- [Running and deploying](#running-and-deploying)
- [Code map](#code-map)

## Concepts

| Term | What it is |
|------|------------|
| **Destination** | One CommCare project paired with one PostgreSQL database. Holds the CommCare API credentials and the database URL (both encrypted at rest). |
| **Token** | A UUID that CommCare HQ sends in the `Authorization` header when forwarding data. Each token belongs to one destination, so the token tells the app which project and database an incoming payload is for. |
| **Destination Source** | A case type to sync into a table. Used by case forwarding (matched by case type) and by the scheduled export sync (uses the export URL). |
| **Form Mapping** | A set of CommCare form names that should be handled together. |
| **Form Mapping Table** | One table that a form mapping writes to, plus the path inside the form JSON to take the data from. A form mapping usually has one table for the top-level form and one extra table per repeat group. |

The management UI is a plain Rails app. Everything below is done from the **Destinations** page unless stated otherwise.

## How to use

### 1. Sign in and manage users

Login is passwordless. Enter your email on the sign-in page and follow the magic link that is emailed to you. Only emails that already exist as users can sign in.

Existing users can add or remove users from the **Users** page in the nav bar. You cannot edit your own user record.

To create the very first user, use the Rails console:

```bash
bin/rails console
User.create!(email: "you@example.org")
```

On Heroku that is `heroku run bin/rails console`.

### 2. Create a destination

**Destinations → New Destination** and fill in:

| Field | Notes |
|-------|-------|
| Name | Friendly label, e.g. "TT Tracker". |
| Project name | The CommCare project slug as it appears in CommCare URLs, e.g. `tt-tracker` in `https://www.commcarehq.org/a/tt-tracker/`. |
| CommCare username | The CommCare web user whose API key is used. |
| API key / password | The user's CommCare API key. Leave blank when editing to keep the existing key. |
| Database URL | `postgres://user:password@host:port/dbname`. The app always connects with `sslmode=require`, replacing any `sslmode` you supply. |

The database user needs permission to `CREATE TABLE` and `ALTER TABLE` in the target schema, as well as `INSERT`, `UPDATE`, and `DELETE`.

### 3. Forward cases

Case forwarding writes one row per case into a table, keyed on the case ID.

**In this app:**

1. Open the destination and click **Add Source**.
   - **Name**: a friendly label.
   - **Case type**: the CommCare case type, e.g. `Patient`. Matching is case-insensitive and ignores surrounding whitespace.
   - **Key column**: use `caseid`. This is the column name the app writes the CommCare case ID to.
   - **Table name**: the destination table, created if it does not exist.
   - **Sensitive fields**: see [Sensitive fields](#6-sensitive-fields).
   - **URL** and **Enable daily sync**: leave blank / unticked unless you also want the [scheduled export sync](#5-sync-an-export-feed-on-a-schedule).
2. Under **API Tokens**, click **Create Token**. Copy the token value.

**In CommCare HQ:**

1. Go to **Project Settings → Data Forwarding** and add a **Forward Cases** connection.
2. Set the URL to `https://<this-app-host>/api/forwarding`.
3. Set the authorization header to `Bearer <token>` (a bare token is also accepted).
4. Either XML or JSON case payloads are accepted. The app only reads the case ID from the payload and then fetches the full case from the CommCare API, so the payload format does not affect the result.

Every case type that a project forwards needs a matching destination source. If a case arrives whose type has no source, the job fails and retries. See [troubleshooting](#7-monitoring-jobs-and-troubleshooting).

A quick way to check the endpoint and token are wired up:

```bash
curl -H "Authorization: Bearer <token>" https://<this-app-host>/api/forwarding
# {"status":"OK"}
```

### 4. Forward forms

Form forwarding flattens each submitted form into one or more tables.

**In this app:**

1. Open the destination and click **Add Form Mapping**.
   - **Name**: a friendly label.
   - **Form names**: comma-separated list of CommCare form names to match, exactly as they appear in the form's `@name` field, e.g. `December Household Consent, Janvier Household Consent`. Matching is case-insensitive.
2. Click **Add Table** on the mapping and add at least one table:
   - **Table name**: destination table.
   - **JSON path**: `.` for the top-level form, or a dot-separated path into the form's JSON for a repeat group, e.g. `consent_survey.oncho_fl.group_indv_ovlf`.
   - **Is Array**: tick this when the path points at a repeat group. One row is written per repeat item. If the path resolves to a single object rather than a list (a repeat group with only one entry does this), it is treated as a one-item list.
   - **Sensitive fields**: see [Sensitive fields](#6-sensitive-fields).
3. Make sure the destination has a token (the same token works for both cases and forms).

**In CommCare HQ:**

1. Go to **Project Settings → Data Forwarding** and add a **Forward Forms** connection with format **JSON**.
2. Use the same URL and `Authorization: Bearer <token>` header as for cases.

The app tells forms and cases apart by looking for a `form.@name` key in the payload, so a single connection URL serves both.

**Finding the JSON path for a repeat group.** Pull a submission from the CommCare form API, or look at a forwarded payload, and follow the nesting under the top-level `form` key. Repeat groups appear as JSON arrays. Nested groups that are *not* repeats do not need their own table. Their fields are flattened into the parent. Arrays that are not given their own table mapping are skipped.

### 5. Sync an export feed on a schedule

This is an alternative to case forwarding for projects where a full daily reload is acceptable, or where you need columns that only an export provides.

1. In CommCare HQ, create a case export and enable **Excel Dashboard Integration**. Copy the feed URL.
2. In this app, create or edit a destination source:
   - **URL**: the export feed URL.
   - **Key column**: the export column that uniquely identifies a row, usually `caseid`.
   - **Table name**: destination table.
   - Tick **Enable daily sync**.
3. Use the **Sync** button on the destination page to run it immediately and check the result.

All sources with daily sync enabled run at **00:00 UTC** each day (configured in `config/initializers/good_job.rb`). Each run:

1. Downloads the export as HTML and streams it row by row.
2. Creates the table if needed, adds any new columns, and **drops columns that are no longer in the export**.
3. Upserts every row.
4. Deletes rows that were not touched by this run, so rows removed in CommCare disappear from the table.

If the export returns zero rows, nothing is deleted. Header names beginning with a non-word character have that character replaced with `_`. Cell values consisting of `---` are written as NULL. Sensitive-field hashing is **not** applied to export syncs.

### 6. Sensitive fields

Each destination source and form mapping table has a **Sensitive fields** list (comma-separated). New records default to the `DEFAULT_SENSITIVE_FIELDS` environment variable.

For each listed field that has a value, the app adds an extra column named `<field> *sensitive*` containing the first 15 hex characters of the SHA-256 hash of the value. This lets analysts join or count on the field without seeing the raw value.

Two things to be aware of:

- **The original column is still written.** Hashing adds a column alongside the raw value rather than replacing it. If a raw value must never reach the destination database, exclude it from the CommCare export or app instead.
- For form tables, a sensitive field name matches any flattened key that either equals it or ends with `.<field>` (which happens when a collision forces a full-path column name).

### 7. Monitoring jobs and troubleshooting

All work happens in background jobs (GoodJob). Signed-in users can open the **Queue** link in the nav bar, or go to `/queue`, to see queued, running, and failed jobs with their errors and backtraces.

Failed jobs retry automatically up to 30 times with increasing delays before being discarded. Common failure causes:

| Symptom in `/queue` | Cause | Fix |
|---------------------|-------|-----|
| `Case type not found: ...` | A case was forwarded whose type has no destination source. | Add a source with that case type. The retries will then succeed. |
| `No form mapping found for form name: '...'` | A form was forwarded whose name is not in any form mapping. | Add the name to a form mapping, or remove the form from the CommCare forwarding rule. |
| `Unknown payload format` | The body was neither JSON nor XML. | Check the CommCare forwarding connection settings. |
| `PG::ConnectionBad` / SSL errors | Database URL wrong, or the server does not accept SSL. | Fix the URL. SSL is mandatory. |
| `PG::InsufficientPrivilege` | The database user cannot create or alter tables. | Grant DDL rights on the schema. |
| `Net::HTTPClientException` on sync | Export URL wrong, or the CommCare API key lacks access. | Re-copy the feed URL and check the CommCare user. |
| CommCare shows the connection as failing | Token deleted or mistyped. Requests get `401 Unauthorized`. | Create a new token and update CommCare. |

The **Last Accessed** column in the API Tokens table shows when CommCare last used each token, which is a quick check that forwarding is alive.

## What gets written to the destination database

All tables are created with `text` columns and a primary key on the key column. Every table also gets a `_last_commcare_sync` timestamp column recording when each row was last written.

You may change a column's type in the destination database to `integer`, `decimal`, or `timestamp without time zone`. Before each write the app checks incoming values against the current column type. If a value does not fit, the column is altered back to `text` and a message is logged.

Column names come straight from CommCare property names, so they may contain characters that need double-quoting in SQL.

### Case tables

Columns are the case's `properties` plus the following:

| Column | Source |
|--------|--------|
| `caseid` | Case ID (the key column) |
| `opened_date` | `date_opened` property, renamed |
| `last_modified_date`, `server_last_modified_date`, `indexed_on_date` | Case metadata |
| `closed`, `closed_date` | Case metadata |
| `opened_by_user_id`, `closed_by_user_id` | Case metadata |
| `opened_by_username`, `closed_by_username` | Looked up from the CommCare user API. The part of the username before `@` only. |
| `owner_name` | Looked up from the CommCare location API using `owner_id`. |
| `indices.<parent_case_type>` | One column per parent index, holding the parent case ID. |
| `<field> *sensitive*` | See [Sensitive fields](#6-sensitive-fields). |

Columns are added as new properties appear but are never dropped by case forwarding.

### Form tables

Each form mapping table receives the leaf values found under its JSON path, flattened:

- Nested (non-repeat) groups are flattened. A leaf uses its own key as the column name, e.g. `age_ovlf`, not `group.subgroup.age_ovlf`.
- If two leaves share the same key, both use their full dot-path as the column name instead.
- Arrays are skipped. Map them with their own table.
- Keys beginning with `@` or `#` (XML attributes and type markers) are skipped, as is the top-level `commcare_usercase` block.
- Null values are skipped.

Every row also gets these metadata columns:

| Column | Source |
|--------|--------|
| `form_instance_id` | The submission ID. Primary key for the top-level (`.`) table. |
| `form_row_id` | `<form_instance_id>_<index>`. Primary key for array tables. Lets you join repeat rows back to the top-level table. |
| `received_on`, `domain`, `app_id` | Submission metadata |
| `meta_instanceID`, `meta_username`, `meta_userID`, `meta_timeStart`, `meta_timeEnd`, `meta_deviceID`, `meta_appVersion` | From the form's `meta` block |
| `<field> *sensitive*` | See [Sensitive fields](#6-sensitive-fields). |

Re-submitting or editing a form overwrites the existing rows for that instance ID. Columns are never dropped by form forwarding.

### Export sync tables

Columns match the export headers exactly (after sanitising leading non-word characters). Columns removed from the export are dropped from the table on the next sync.

## Running and deploying

### Prerequisites

- Ruby 3.4.8 (see `.ruby-version`)
- PostgreSQL (for the app's own database; destinations are separate)
- A CommCare HQ web user with API access to each project
- An SMTP account for sign-in emails

### Environment variables

Copy `.env.example` to `.env` and fill in:

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | This app's own PostgreSQL database. |
| `HOST` | Public host used in sign-in email links, e.g. `commcare-utils.example.org`. |
| `EMAILER_HOST`, `EMAILER_PORT`, `EMAILER_DOMAIN`, `EMAILER_USERNAME`, `EMAILER_PASSWORD` | SMTP settings for sign-in emails. |
| `EMAILER_FROM` | From address for sign-in emails. |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | Keys for encrypting destination database URLs and CommCare API keys. Generate with `bin/rails db:encryption:init`. Losing these makes existing destinations unreadable. |
| `DEFAULT_SENSITIVE_FIELDS` | Default comma-separated sensitive field list for new sources and form tables, e.g. `name,patient_id,phone_number`. |

### Local development

```bash
bundle install
bin/rails db:create db:migrate
bin/rails console   # then: User.create!(email: "you@example.org")
bin/dev
```

`bin/dev` uses `Procfile.dev` to start Puma on port 3000, the DartSass watcher, and a GoodJob worker. Without the worker nothing will be forwarded or synced.

### Heroku

The app is set up for Heroku with a `web` dyno, a `worker` dyno running GoodJob, and a `release` phase that runs migrations:

```bash
git push heroku main
heroku ps:scale web=1 worker=1
```

Set all environment variables above as config vars. The scheduled sync is driven by GoodJob's built-in cron inside the worker dyno, so no Heroku Scheduler add-on is required. The worker must be running for the schedule to fire.

A `Dockerfile` and Kamal `config/deploy.yml` are also present but the deploy config still contains Rails template placeholders (including a Solid Queue setting that this app does not use). Treat Heroku as the supported path.

## Code map

| Path | Role |
|------|------|
| `app/models/destination.rb` | Credentials, and the entry points `handle_forwarded_case` and `handle_forwarded_form`. |
| `app/models/destination_source.rb` | Case sync (`sync_case`) and export feed sync (`sync_source`). |
| `app/models/destination_token.rb` | Webhook tokens and `authenticate`. |
| `app/models/form_mapping.rb`, `form_mapping_table.rb` | Form name matching and per-table JSON path config. |
| `app/services/form_flattener.rb` | Flattens a form payload into rows for each form mapping table. |
| `app/models/concerns/table_writable.rb` | Shared table creation, column reconciliation, type coercion, upsert, and export HTML parsing. |
| `lib/database_writer.rb` | Raw `pg` connection and DDL/DML against the destination database. |
| `lib/commcare_client.rb` | CommCare HQ API calls for cases, users, and locations. |
| `app/controllers/api/data_forwarding_controller.rb` | `GET`/`POST /api/forwarding` webhook. Enqueues `DataForwardJob`. |
| `app/jobs/data_forward_job.rb` | Detects case vs form payload and dispatches to the destination. |
| `app/jobs/sync_all_sources_job.rb`, `sync_source_job.rb` | Daily fan-out and per-source export sync. |
| `config/initializers/good_job.rb` | Cron schedule for the daily sync. |
| `lib/user_constraint.rb` | Restricts the `/queue` dashboard to signed-in users. |

### Tech stack

Rails 8.1, Ruby 3.4.8, PostgreSQL, GoodJob 4 (database-backed jobs and cron), Passwordless (magic-link login), Hotwire, Bootstrap 5, DartSass.
