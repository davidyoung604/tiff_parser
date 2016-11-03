require 'tiff_parser/ifd/ifd_record'

class TIFFParser
  # Image File Directory, according to the spec for TIFF files
  class IFD
    IFD_HEADER = [
      { name: :num_records, offset: 0, length: 2, type: :uint }
    ].freeze

    IFD_NEXT = [
      { name: :next_offset, offset: 0, length: 4, type: :uint }
    ].freeze

    attr_reader :next_offset, :records

    # file should be a PackTheBin object
    def initialize(file, offset = 0)
      @file = file
      @offset = offset
      @next_offset = nil # undefined until after load_records
      @first_rec_offset = @offset + PackTheBin.size(IFD_HEADER)
      load_records
    end

    def ifd_header
      @file.read_fields(IFD_HEADER, @offset)
    end

    private_class_method

    def self.record_size
      PackTheBin.size(IFDRecord::IFD_RECORD)
    end

    private

    def load_records
      @records = read_n_ifd_records(ifd_header[:num_records], @first_rec_offset)
      @next_offset = @file.read_fields(IFD_NEXT, @first_rec_offset +
        (@records.count * self.class.record_size))[:next_offset]
      @records
    end

    def read_n_ifd_records(num_recs, first_offset)
      (0...num_recs).to_a.map do |rec_num|
        IFDRecord.new(@file, first_offset + (rec_num * self.class.record_size))
      end
    end
  end
end
