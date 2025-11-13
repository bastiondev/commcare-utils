# Example Case payload formats:
# XML: 
# <case case_id="b0916685-7247-4c44-b712-633d3d64e0c0"
#     date_modified="2015-04-17T16:04:54.950000Z"
#     user_id="d0e472a6b36dfd3ee5059222e12b8c1b"
#     xmlns="http://commcarehq.org/case/transaction/v2">
#   <create>
#     <case_type>mscase</case_type>
#     <case_name>Trees</case_name>
#     <owner_id>d0e472a6b36dfd3ee5059222e12b8c1b</owner_id>
#   </create>
# </case>
# JSON:
#  { "case_id" : "b0916685-7247-4c44-b712-633d3d64e0c0",    
#     "closed" : false,
#     "date_closed" : null,
#     "date_modified" : "2015-04-17T16:04:54.950000Z",
#     "domain" : "demo",
#     "indices" : {  },
#     "properties" : {
#         "case_name" : "Trees",
#         "case_type" : "mscase",
#         "date_opened" : "2012-03-13T18:21:52Z",
#         "owner_id" : "d0e472a6b36dfd3ee5059222e12b8c1b",
#       },
#     "server_date_modified" : "2012-04-05T23:56:41Z",
#     "server_date_opened" : "2012-04-05T23:56:41Z",
#     "user_id" : "d0e472a6b36dfd3ee5059222e12b8c1b",
#     "version" : "2.0",
#     "xform_ids" : [ "3HQEXR2S0GIRFY2GF40HAR7ZE" ]
#   }

class DataForwardJob < ApplicationJob
  queue_as :default

  def perform(destination_token_id, payload)
    destination_token = DestinationToken.find(destination_token_id)
    destination = destination_token.destination

    # Update last_accessed_at timestamp
    destination_token.update(last_accessed_at: Time.current)

    parsed_payload = parse_payload(payload)
    
    destination.handle_forwarded_case(parsed_payload[:case_id])
  end

  # Extract the payload into case_name and case_id
  # Payload is either and XML or JSON string
  # Return hash:
  # {
  #   case_name: "Trees",
  #   case_id: "b0916685-7247-4c44-b712-633d3d64e0c0"
  # }
  def parse_payload(payload)
    payload_str = payload.is_a?(String) ? payload : payload.to_s
    stripped = payload_str.strip
    
    # Detect format by checking first non-whitespace character
    if stripped.start_with?('{', '[')
      parse_json(stripped)
    elsif stripped.start_with?('<')
      parse_xml(stripped)
    else
      raise "Unknown payload format: #{stripped[0..50]}"
    end
  end

  private

  def parse_json(json_str)
    data = JSON.parse(json_str)
    {
      case_name: data.dig('properties', 'case_name'),
      case_id: data['case_id']
    }
  rescue JSON::ParserError => e
    raise "Failed to parse JSON: #{e.message}"
  end

  def parse_xml(xml_str)
    doc = Nokogiri::XML(xml_str)
    case_element = doc.root
    
    {
      case_name: case_element.xpath('.//case_name').first&.text,
      case_id: case_element.attr('case_id')
    }
  rescue => e
    raise "Failed to parse XML: #{e.message}"
  end
  
end
