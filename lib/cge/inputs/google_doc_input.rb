require 'cge/input'
require 'google/apis/docs_v1'
require 'googleauth'

module CGE
  # An input that fetches the contents of a Google Doc as raw text
  class GoogleDocInput < Input
    attr_option 'document_id', String, :required do |val|
      val.length > 10 && val.match(/^[a-zA-Z0-9_-]+$/)
    end
    attr_option 'credentials_path', String, :optional do |val|
      File.exist?(val)
    end
    attr_output 'content', String

    protected

    def invoke
      service = Google::Apis::DocsV1::DocsService.new
      service.authorization = authorize

      document = service.get_document(document_id.value)
      @content = extract_text_from_document(document)
    rescue Google::Apis::Error => e
      raise GoogleDocError, "Google API error: #{e.message}"
    rescue StandardError => e
      raise GoogleDocError, "Failed to fetch document: #{e.message}"
    end

    private

    def authorize
      if credentials_path.value
        scope = ['https://www.googleapis.com/auth/documents.readonly']
        Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: File.open(credentials_path.value),
          scope: scope
        )
      else
        Google::Auth.get_application_default(['https://www.googleapis.com/auth/documents.readonly'])
      end
    end

    def extract_text_from_document(document)
      return '' unless document.body && document.body.content

      document.body.content.map { |element| extract_text_from_element(element) }.join
    end

    def extract_text_from_element(element)
      return extract_paragraph_text(element) if element.paragraph
      return extract_table_text(element) if element.table

      ''
    end

    def extract_paragraph_text(element)
      return '' unless element.paragraph.elements

      element.paragraph.elements.map do |paragraph_element|
        paragraph_element.text_run ? (paragraph_element.text_run.content || '') : ''
      end.join
    end

    def extract_table_text(element)
      return '' unless element.table.table_rows

      element.table.table_rows.map do |row|
        next unless row.table_cells

        row.table_cells.map do |cell|
          next unless cell.content

          cell.content.map { |cell_element| extract_text_from_element(cell_element) }.join
        end.compact.join
      end.compact.join
    end
  end

  class GoogleDocError < StandardError
  end
end
