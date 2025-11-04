class DatabaseWriter

  TYPEMAP = {
    "string" => "text",
    "integer" => "integer",
    "float" => "decimal",
    "datetime" => "timestamp without time zone"
  }

  TYPEMATCHERS = {
    "string" => ".+",
    "integer" => "^[-+]?\\d{1,9}$",
    "float" => "^[-+]?[0-9]+(\\.[0-9]*)?$"
  }

  def initialize url
    # Establish connection in URL
    uri = URI url
    @conn = PG.connect(host: uri.host, port: uri.port, user: uri.user, 
      password: uri.password, dbname: uri.path.sub(/\A\//, ''))
  end

  def close
    @conn.close
  end

  def create table_name, columns
    query = %(CREATE TABLE IF NOT EXISTS "#{table_name}" \()
    query << columns.map{|col| "\"#{col}\" text" }.join(", ")
    query << ");"
    exec_params query, []
  end

  def set_primary_key table_name, column
    exec_params(%(ALTER TABLE "#{table_name}" DROP CONSTRAINT IF EXISTS "#{table_name}_pkey";))
    exec_params(%(ALTER TABLE "#{table_name}" ADD PRIMARY KEY ("#{column}");))
  end

  def exists? table_name
    query = %(
      SELECT * FROM information_schema.columns
      WHERE table_name = '#{table_name}'
      LIMIT 1;
    )
    exec_params(query).count > 0
  end

  def get_table_columns table_name
    query = %(
      SELECT * FROM information_schema.columns
      WHERE table_name = '#{table_name}';
    )
    exec_params(query).map do |r| 
      {name: r["column_name"], type: TYPEMAP.key(r["data_type"])}
    end
  end

  def add_column table_name, column
    query = %(
      ALTER TABLE "#{table_name}"
      ADD COLUMN "#{column}" text;
    )
    exec_params(query)
  end

  def drop_column table_name, column
    query = %(
      ALTER TABLE "#{table_name}"
      DROP COLUMN "#{column}";
    )
    exec_params(query)
  end

  def set_column_type table_name, column, type
    query = %(
      ALTER TABLE "#{table_name}"
      ALTER COLUMN "#{column}" TYPE #{TYPEMAP[type]}
      USING "#{column}"::#{TYPEMAP[type]};
    )
    exec_params(query)
  end

  def all_rows_are_type? table_name, column, type
    query = %(
      SELECT count(*) as count FROM "#{table_name}"
      WHERE NOT "#{column}"::text ~ '#{TYPEMATCHERS[type]}'
    )
    return exec_params(query)[0]['count'].to_i <= 0
  end

  def drop_table table_name
    exec_params("DROP TABLE IF EXISTS \"#{table_name}\"")
  end

  def upsert_values table_name, key, values
    # values: {column => value}
    columns = []
    params = []
    values.each do |k,v| 
      columns << %("#{k}")
      params << v
    end
    query = %(
      INSERT INTO "#{table_name}" (#{columns.join(',')})
      VALUES (#{(1..params.length).map{|i| "$#{i}" }.join(',')})
      ON CONFLICT ("#{key}") DO UPDATE
      SET #{(1..params.length).map{|i| "#{columns[i-1]} = $#{i}"}.join(', ')}
    )
    exec_params(query, params)
  end

  def delete table_name, key
    # Deletes the row specified by key
  end

  def delete_before table_name, column_name, datetime
    exec_params(%(DELETE FROM "#{table_name}" where NOT "#{column_name}" >= $1;),[datetime])
  end

  private 

    def exec_params query, params=[]
      @conn.exec_params query, params
    end

end