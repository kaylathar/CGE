require 'cge/input'
require 'rtesseract'

module CGE
  # An input that performs OCR on an image file and extracts text content
  class OCRInput < Input
    IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .tiff .bmp .gif .pdf].freeze

    attr_input 'image_path', String, :required do |val|
      !val.nil? && !val.empty? && File.readable?(val) && IMAGE_EXTENSIONS.include?(File.extname(val).downcase)
    end
    attr_input 'language', String
    attr_output 'text', String

    protected

    def invoke
      @text = ocr_image_at_path(image_path.value, language.value)
    rescue StandardError => e
      raise OCRInputError, "OCR processing failed: #{e.message}"
    end

    def ocr_image_at_path(path, language = nil)
      options = { image: path }
      options[:lang] = language if language

      image = RTesseract.new(options)
      image.to_s.gsub(/\s+/, ' ').strip
    end

    private :ocr_image_at_path
  end

  class OCRInputError < StandardError
  end
end
CGE::Command.register_command(CGE::OCRInput)
