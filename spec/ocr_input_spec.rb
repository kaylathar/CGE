require 'spec_helper'

describe DAF::OCRInput do
  let(:ocr_input) { DAF::OCRInput.new("test_input", {}) }
  let(:test_image_path) { '/path/to/test_image.png' }
  let(:options) { { 'image_path' => test_image_path } }
  let(:mock_rtesseract) { double('RTesseract') }

  def stub_valid_image(path = test_image_path, extension = '.png')
    allow(File).to receive(:readable?).with(path).and_return(true)
    allow(File).to receive(:extname).with(path).and_return(extension)
  end

  def stub_ocr_result(text = 'Sample OCR text')
    allow(RTesseract).to receive(:new).and_return(mock_rtesseract)
    allow(mock_rtesseract).to receive(:to_s).and_return(text)
  end

  before do
    stub_valid_image
    stub_ocr_result
  end

  it 'should extract text from image using OCR' do
    ocr_input.execute(options, nil)
    expect(ocr_input.text).to eq('Sample OCR text')
  end

  it 'should raise error when image_path is empty' do
    expect { ocr_input.execute({ 'image_path' => '' }, nil) }
      .to raise_error(DAF::OptionError, /Bad value for option image_path/)
  end

  it 'should raise error when image file is not accessible' do
    allow(File).to receive(:readable?).with(test_image_path).and_return(false)
    
    expect { ocr_input.execute(options, nil) }
      .to raise_error(DAF::OptionError, /Bad value for option image_path/)
  end

  it 'should validate supported image formats' do
    valid_formats = ['.png', '.jpg', '.jpeg', '.tiff', '.bmp', '.gif', '.pdf']
    
    valid_formats.each do |format|
      allow(File).to receive(:extname).with(test_image_path).and_return(format)
      expect { ocr_input.execute(options, nil) }.not_to raise_error
    end
  end

  it 'should raise error for unsupported image formats' do
    allow(File).to receive(:extname).with(test_image_path).and_return('.txt')
    
    expect { ocr_input.execute(options, nil) }
      .to raise_error(DAF::OptionError, /Bad value for option image_path/)
  end

  it 'should pass language option to RTesseract' do
    options_with_lang = options.merge('language' => 'spa')
    
    expect(RTesseract).to receive(:new).with(
      hash_including(image: test_image_path, lang: 'spa')
    ).and_return(mock_rtesseract)
    
    ocr_input.execute(options_with_lang, nil)
  end

  it 'should clean up whitespace in OCR results' do
    allow(mock_rtesseract).to receive(:to_s).and_return("  Multiple   spaces\n\nand   newlines  ")
    
    ocr_input.execute(options, nil)
    expect(ocr_input.text).to eq('Multiple spaces and newlines')
  end

  it 'should handle empty OCR results' do
    allow(mock_rtesseract).to receive(:to_s).and_return('   ')
    
    ocr_input.execute(options, nil)
    expect(ocr_input.text).to eq('')
  end

  it 'should handle RTesseract errors' do
    allow(RTesseract).to receive(:new).and_raise(StandardError.new('Tesseract error'))
    
    expect { ocr_input.execute(options, nil) }
      .to raise_error(DAF::OCRInputError, /OCR processing failed.*Tesseract error/)
  end

end