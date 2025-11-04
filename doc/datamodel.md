## CommCare projects sync

## `destinations`

* `id` - Primary Key
* `name` - Name of the destination
* `database_url` - encrypted text - URL of the database
* `commcare_username` - CommCare username
* `commcare_password` - encrypted text - CommCare password
* `updated_at` - Timestamp of the last update
* `created_at` - Timestamp of the creation

## `destination_sources`

* `id` - Primary Key
* `destination_id` - Foreign Key to `destinations`
* `name` - Name of the source
* `url` - URL of the source
* `key_column` - Key column of the source
* `table_name` - Table name of the source
* `updated_at` - Timestamp of the last update
* `created_at` - Timestamp of the creation

