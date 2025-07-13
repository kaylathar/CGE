require 'spec_helper'

describe CGE::OCRInput do
  let(:ocr_input) { CGE::OCRInput.new('ocr_input_id', "test_input", {}, nil) }
  let(:test_image_path) { '/path/to/test_image.png' }
  let(:inputs) { { 'image_path' => test_image_path } }
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
    mock_graph = double('CommandGraph')
    ocr_input.execute(inputs, nil, mock_graph)
    expect(ocr_input.text).to eq('Sample OCR text')
  end

  it 'should raise error when image_path is empty' do
    mock_graph = double('CommandGraph')
    expect { ocr_input.execute({ 'image_path' => '' }, nil, mock_graph) }
      .to raise_error(CGE::InputError, /Bad value for input image_path/)
  end

  it 'should raise error when image file is not accessible' do
    allow(File).to receive(:readable?).with(test_image_path).and_return(false)
    
    mock_graph = double('CommandGraph')
    expect { ocr_input.execute(inputs, nil, mock_graph) }
      .to raise_error(CGE::InputError, /Bad value for input image_path/)
  end

  it 'should validate supported image formats' do
    valid_formats = ['.png', '.jpg', '.jpeg', '.tiff', '.bmp', '.gif', '.pdf']
    
    valid_formats.each do |format|
      allow(File).to receive(:extname).with(test_image_path).and_return(format)
      mock_graph = double('CommandGraph')
      expect { ocr_input.execute(inputs, nil, mock_graph) }.not_to raise_error
    end
  end

  it 'should raise error for unsupported image formats' do
    allow(File).to receive(:extname).with(test_image_path).and_return('.txt')
    
    mock_graph = double('CommandGraph')
    expect { ocr_input.execute(inputs, nil, mock_graph) }
      .to raise_error(CGE::InputError, /Bad value for input image_path/)
  end

  it 'should pass language option to RTesseract' do
    inputs_with_lang = inputs.merge('language' => 'spa')
    
    expect(RTesseract).to receive(:new).with(
      hash_including(image: test_image_path, lang: 'spa')
    ).and_return(mock_rtesseract)
    
    mock_graph = double('CommandGraph')
    ocr_input.execute(inputs_with_lang, nil, mock_graph)
  end

  it 'should clean up whitespace in OCR results' do
    allow(mock_rtesseract).to receive(:to_s).and_return("  Multiple   spaces\n\nand   newlines  ")
    
    mock_graph = double('CommandGraph')
    ocr_input.execute(inputs, nil, mock_graph)
    expect(ocr_input.text).to eq('Multiple spaces and newlines')
  end

  it 'should handle empty OCR results' do
    allow(mock_rtesseract).to receive(:to_s).and_return('   ')
    
    mock_graph = double('CommandGraph')
    ocr_input.execute(inputs, nil, mock_graph)
    expect(ocr_input.text).to eq('')
  end

  it 'should handle RTesseract errors' do
    allow(RTesseract).to receive(:new).and_raise(StandardError.new('Tesseract error'))
    
    mock_graph = double('CommandGraph')
    expect { ocr_input.execute(inputs, nil, mock_graph) }
      .to raise_error(CGE::OCRInputError, /OCR processing failed.*Tesseract error/)
  end

end