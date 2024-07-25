require 'pdf-reader'
require 'prawn'
require 'prawn/table'
require 'ruby-progressbar'

class VoucherPDFGenerator
  Prawn::Fonts::AFM.hide_m17n_warning = true

  def initialize(input_pdf_path:, output_pdf_path:, template_path:)
    @input_pdf_path = input_pdf_path
    @output_pdf_path = output_pdf_path
    @template_path = template_path
    @number_pattern = /\b\d+-\d+\b/
  end

  def process_pdf
    numbers = extract_numbers
    template = read_template
    table_data = prepare_table_data(numbers, template)
    generate_pdf(table_data)
    puts "PDF created successfully at #{@output_pdf_path}"
  end

  private

  def extract_numbers
    reader = PDF::Reader.new(@input_pdf_path)
    numbers = []
    total_pages = reader.page_count
    batch_size = 10
    total_batches = (total_pages / batch_size.to_f).ceil

    batch_progress = ProgressBar.create(title: "Batches", total: total_batches, format: "%t: |%B| %p%% %a")

    reader.pages.each_slice(batch_size).with_index(1) do |slice, batch_index|
      page_progress = ProgressBar.create(title: "Batch #{batch_index} Pages", total: slice.size, format: "%t: |%B| %p%% %a")

      slice.each_with_index do |page, page_index|
        numbers.concat(page.text.scan(@number_pattern))
        page_progress.increment
      end

      batch_progress.increment
    end

    numbers
  end

  def read_template
    File.read(@template_path)
  end

  def prepare_table_data(numbers, template)
    numbers.map do |number|
      template.gsub('%{number}', "#{number}")
    end
  end

  def cell_style_options
    {
      border_width: 1,
      border_color: '000000',
      padding: 5,
      inline_format: true,
      align: :center,
      valign: :center
    }
  end

  def generate_pdf(table_data)
    output_folder = File.join(Dir.home, 'Desktop', 'pdf_vouchers')

    Dir.mkdir(output_folder) unless Dir.exist?(output_folder)

    output_file = File.join(output_folder, @output_pdf_path)

    Prawn::Document.generate(output_file) do |pdf|
      pdf.font_size 10

      total_slices = (table_data.size / 2.0).ceil
      table_progress = ProgressBar.create(title: "Generating PDF", total: total_slices, format: "%t: |%B| %p%% %a")

      table_data.each_slice(2) do |slice|
        slice << 'empty' if slice.size < 2

        row = [slice[0], '', slice[1]]

        pdf.table([row], cell_style: cell_style_options) do
          cells.border_lines = [:dashed]
          row(0).height = 125
          cells.each do |cell|
            if cell.content == 'empty'
              cell.content = ''
              cell.width = 260
              cell.height = 125
            end
          end
        end

        pdf.move_down 15
        table_progress.increment
      end
    end
  end
end

input_pdf_path = 'vouchers.pdf'
output_pdf_path = "output_vouchers.pdf"
template_path = 'template.txt'

pdf_service = VoucherPDFGenerator.new(input_pdf_path: input_pdf_path, output_pdf_path: output_pdf_path, template_path: template_path)
pdf_service.process_pdf
