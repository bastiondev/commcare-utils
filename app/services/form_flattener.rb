require 'digest'

class FormFlattener
  EXCLUDED_KEYS = %w[commcare_usercase].freeze
  XML_ARTIFACT_KEYS = /\A[@#]/
  META_FIELDS = %w[instanceID username userID timeStart timeEnd deviceID appVersion].freeze

  def initialize(form_payload, form_mapping)
    @payload = form_payload
    @mapping = form_mapping
    @form_instance_id = form_payload['id'] || form_payload.dig('form', 'meta', 'instanceID')
    @meta = extract_meta_fields
  end

  def process!
    @mapping.form_mapping_tables.each do |fmt|
      data_at_path = navigate_to_path(fmt.json_path)
      next if data_at_path.nil?

      sensitive_list = parse_sensitive_fields(fmt)

      if data_at_path.is_a?(Array)
        process_repeat_group(fmt, data_at_path, sensitive_list)
      elsif data_at_path.is_a?(Hash)
        process_single_object(fmt, data_at_path, sensitive_list)
      else
        Rails.logger.warn "FormFlattener: path '#{fmt.json_path}' resolved to a non-object/array value, skipping"
      end
    end
  end

  private

  def navigate_to_path(json_path)
    return @payload['form'] if json_path == '.'

    parts = json_path.split('.')
    current = @payload['form']
    parts.each do |part|
      return nil unless current.is_a?(Hash)
      current = current[part]
    end
    current
  end

  def extract_meta_fields
    meta = {}
    form_meta = @payload.dig('form', 'meta') || {}

    META_FIELDS.each do |field|
      value = form_meta[field]
      meta["meta_#{field}"] = value if value.is_a?(String) || value.is_a?(Numeric)
    end

    meta['form_instance_id'] = @form_instance_id
    meta['received_on'] = @payload['received_on']
    meta['domain'] = @payload['domain']
    meta['app_id'] = @payload['app_id']
    meta
  end

  # Flatten a hash into {column_name => value} using terminal key names.
  # If two terminal names collide, both use their full dot-path instead.
  def flatten_object(obj, prefix = '')
    terminals = []
    collect_terminals(obj, prefix, terminals)

    short_name_counts = terminals.group_by { |t| t[:short] }

    result = {}
    terminals.each do |t|
      if short_name_counts[t[:short]].length > 1
        result[t[:full_path]] = t[:value]
      else
        result[t[:short]] = t[:value]
      end
    end
    result
  end

  # Recursively collect terminal (leaf) values from a nested hash.
  def collect_terminals(obj, prefix, accumulator)
    return unless obj.is_a?(Hash)

    obj.each do |key, value|
      next if prefix.empty? && EXCLUDED_KEYS.include?(key)
      next if key.match?(XML_ARTIFACT_KEYS)

      full_path = prefix.empty? ? key : "#{prefix}.#{key}"

      case value
      when Hash
        collect_terminals(value, full_path, accumulator)
      when Array
        # Arrays should be mapped as separate FormMappingTables
        next
      when NilClass
        next
      else
        accumulator << { short: key, full_path: full_path, value: value.to_s }
      end
    end
  end

  def process_single_object(fmt, obj, sensitive_list)
    flat = flatten_object(obj)
    flat.merge!(@meta)
    apply_sensitive_hashing!(flat, sensitive_list)

    columns = flat.keys
    fmt.ensure_table(columns)
    fmt.upsert_row(columns, flat.values, DateTime.now)
  end

  def process_repeat_group(fmt, array, sensitive_list)
    array.each_with_index do |element, index|
      next unless element.is_a?(Hash)

      flat = flatten_object(element)
      flat.merge!(@meta)
      flat['form_row_id'] = "#{@form_instance_id}_#{index}"
      apply_sensitive_hashing!(flat, sensitive_list)

      columns = flat.keys
      fmt.ensure_table(columns)
      fmt.upsert_row(columns, flat.values, DateTime.now)
    end
  end

  def parse_sensitive_fields(fmt)
    (fmt.sensitive_fields || '').split(',').map(&:strip).reject(&:blank?)
  end

  def apply_sensitive_hashing!(flat, sensitive_list)
    sensitive_list.each do |field|
      matching_keys = flat.keys.select { |k| k == field || k.end_with?(".#{field}") }
      matching_keys.each do |key|
        if flat[key].present?
          flat["#{key} *sensitive*"] = Digest::SHA256.hexdigest(flat[key])[0, 15]
        end
      end
    end
  end
end
