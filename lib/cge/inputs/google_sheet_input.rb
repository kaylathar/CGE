require 'cge/input'
require 'google/apis/sheets_v4'
require 'googleauth'

module CGE
  # An input that fetches the contents of a Google Sheet as raw text
  # Returns content as tab-separated values with rows separated by newlines
  class GoogleSheetInput < Input
    attr_input 'spreadsheet_id', String, :required do |val|
      # Google Sheets ID format: 44 characters, alphanumeric with hyphens and underscores
      val.length >= 40 && val.match(/^[a-zA-Z0-9_-]{40,}$/)
    end
    attr_input 'credentials_path', String do |val|
      File.exist?(val)
    end
    attr_input 'range', String
    attr_output 'content', String

    protected

    def invoke
      service = Google::Apis::SheetsV4::SheetsService.new
      service.authorization = authorize

      range_name = range.value || 'A:ZZ'
      response = service.get_spreadsheet_values(spreadsheet_id.value, range_name)
      @content = extract_text_from_response(response)
    rescue Google::Apis::Error => e
      raise GoogleSheetError, "Google API error: #{e.message}"
    rescue StandardError => e
      raise GoogleSheetError, "Failed to fetch spreadsheet: #{e.message}"
    end

    private

    def authorize
      if credentials_path.value
        scope = ['https://www.googleapis.com/auth/spreadsheets.readonly']
        Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: File.open(credentials_path.value),
          scope: scope
        )
      else
        Google::Auth.get_application_default(['https://www.googleapis.com/auth/spreadsheets.readonly'])
      end
    end

    # Converts sheet response to tab-separated text format
    # Each row becomes a line, with cells separated by tabs
    def extract_text_from_response(response)
      return '' unless response.values

      response.values.map do |row|
        row.join("\t")
      end.join("\n")
    end
  end

  class GoogleSheetError < StandardError
  end
end
CGE::Command.register_command(CGE::GoogleSheetInput)
