require 'database_writer'
require 'net/http'
require 'json'

module TableWritable
  extend ActiveSupport::Concern

  NULL_PATTERN = /---/
  LAST_SYNC_COLUMN = '_last_commcare_sync'

  def ensure_table _columns
    # Add the last_sync column
    columns = _columns + [LAST_SYNC_COLUMN]

    # If table_name doesn't exist, create it.
    unless writer.exists?(table_name)
      writer.create table_name, columns

    # Go through columns and add to table as text (or type if in types) 
    # if don't exist, or alter to type if needed (and can) from types
    # Don't remove the 
    else
      current_columns = writer.get_table_columns(table_name).map{|c| c[:name]}
      columns_to_add = columns.reject{|c| current_columns.include?(c)}
      columns_to_remove = current_columns.select{|c| !columns.include?(c)}
      columns_to_add.each {|col| writer.add_column(table_name, col) }
      columns_to_remove.each {|col| writer.drop_column(table_name, col) }
    end

    # Ensure unique constraint exists on key column, named "commcare_key_constraint"
    writer.set_primary_key table_name, key_column
  end

  def upsert_row _columns, _values, time
    # Replace NULL_PATTERN with nil and make sure all strings
    values = _values.map(&:to_s).map{|v| v =~ NULL_PATTERN ? nil : v}

    # Add last_sync timestamps
    columns = _columns + [LAST_SYNC_COLUMN]
    values << time

    # Ensure column types are all valid for values, if not coerce back to string
    current_columns = writer.get_table_columns(table_name)
    columns.each_with_index do |column, i|
      value = values[i]
      current_column = current_columns.find{|c| c[:name] == column}
      unless value.nil? || is_type?(value, current_column[:type])
        Rails.logger.info("Coercing #{table_name}.#{column} back to string to accomodate '#{value}'")
        writer.set_column_type table_name, column, 'string' 
      end
    end

    # Upsert values into table_name
    values_to_upsert = {}
    columns.each_with_index{|c,i| values_to_upsert[c] = values[i]}
    writer.upsert_values table_name, key_column, values_to_upsert
  end

  # LAST_SYNC_COLUMN is set to time when inserted by sync, delete
  # any rows not synced
  def delete_rows_updated_before time
    writer.delete_before table_name, LAST_SYNC_COLUMN, time
  end

  def writer
    @database_writer ||= DatabaseWriter.new(destination.database_url)
  end

  def finish_writer
    @database_writer.close
    @database_writer = nil
  end

  def sanitize_headers headers
    headers.map do |header|
      header.gsub /^\W/, '_'
    end
  end

  def is_type? value, type
    case type
    when "string"
      true
    when "integer"
      value.is_a?(Integer) || value =~ /\A[-+]?\d+\z/
    when "float"
      value.is_a?(Float) || value =~ /\A[-+]?[0-9]+(\.[0-9]*)?\z/
    when "datetime"
      value.is_a?(DateTime) ||
      (!!Date.strptime(value, '%F %T') rescue false)
    else
      false
    end
  end

  def parse_source &block
    parser = Nokogiri::HTML::SAX::PushParser.new(
      Class.new(Nokogiri::XML::SAX::Document) {
        def initialize _block
          @stack = []
          @row_values = []
          @block = _block
          @current_value = ''
        end
        def start_element(name, attrs = [])
          @stack.push(name)
          if name == 'td'
            @current_value = ''
          end
        end
        def end_element(element)
          @stack.pop if (element == @stack.last)
          if element == 'tr'
            @block.call @row_values
            @row_values = []
          elsif ['th','td'].include?(element)
            @row_values.push(@current_value)
            @current_value = ''
          end
        end
        def characters(value)
          if ['th','td'].include? @stack.last
            @current_value << value
          end
        end
      }.new(block)
    )
    auth_header = "ApiKey #{destination.commcare_username}:#{destination.commcare_password}"
    uri = URI url

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Get.new uri
      request['Authorization'] = auth_header
      http.request(request)
      # http.request request do |response|
      #   response.read_body do |chunk|
      #     parser << chunk
      #   end
      # end
    end
    string_io = StringIO.new(response.body)
    until string_io.eof?
      parser <<  string_io.read(3000)
    end
    parser.finish
  end


end