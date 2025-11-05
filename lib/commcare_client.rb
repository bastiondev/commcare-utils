require 'net/http'
require 'json'

class CommcareClient

  def initialize(username, api_key, project_name)
    @username = username
    @api_key = api_key
    @project_name = project_name
  end

  def get_case(case_id)
    execute_get("https://www.commcarehq.org/a/#{@project_name}/api/case/v2/#{case_id}")
  end

  private 

  def execute_get(url)
    response = Net::HTTP.get(URI.parse(url), { 'Authorization' => "ApiKey #{@username}:#{@api_key}" })
    JSON.parse(response)
  end
end