require 'tiff_parser/ifd/ifd_record_headers'

class TIFFParser
  class IFD
    # A record within an IFD (e.g. ImageWidth, ImageHeight)
    class IFDRecord
      attr_accessor :tag, :type, :data_size, :data

      include IFDRecordHeaders

      def initialize(file, offset = 0, data_field_size = 4)
        @file = file
        @offset = offset
        @data_field_size = data_field_size
        read_self
      end

      def tag_name
        TAGS.key?(@tag) ? TAGS[@tag][:name] : '(unknown)'
      end

      def to_s
        "Tag name: #{tag_name}\n" \
        "Tag value: #{tag}\n" \
        "Type: #{type}\n" \
        "Total bytes: #{data_size}\n" \
        "Data: #{data}\n"
      end

      private

      # if the data is <= 4 bytes, it'll be stored in the field.
      # otherwise, those 4 bytes are the offset of data.
      def data_fits?
        @data_size <= @data_field_size
      end

      def fix_short_strings
        return unless data_fits? && @type == 2
        @data = PackTheBin.convert(@data,
                                   { type: :uint, size: 4 },
                                   { type: :str, size: '*' }).first
      end

      def fetch_long_data
        # types 1, 2, 6, 7 need to be read in as a continuous block.
        # all other types need to be read in as individual entries
        n_blocks = [1, 2, 6, 7].include?(@type) ? 1 : @count

        custom_fields = []
        n_blocks.times do |i|
          custom_fields << { name: :"data_#{i}", length: @data_size / n_blocks,
                             type: TYPES[@type][:data_type] }
        end

        temp = @file.read_fields(custom_fields, @data)
        @data = []
        n_blocks.times { |i| @data << temp[:"data_#{i}"] }
      end

      def fix_rational_data
        case @type
        when 5 # unsigned rational (see IFDRecordHeaders::TYPES)
          type = :uint
        when 10 # signed rational (see IFDRecordHeaders::TYPES)
          type = :int
        else
          return
        end

        @data.map! do |d|
          PackTheBin.convert(d, { type: type, size: 8 },
                             { type: type, size: 4, count: 2 })
        end
      end

      # some of the data needs to be re-processed after it's brought in
      # (e.g. type 5 is rational, so take uint64 and turn it into uint32 * 2)
      def fix_special_data
        fix_rational_data
        # data processing expects arrays. extract if it's the only entry
        @data = @data.first if @data.count == 1
      end

      def read_self
        @fields = @file.read_fields(IFD_RECORD, @offset)
        @fields.each { |k, v| instance_variable_set("@#{k}", v) }
        # special case for length because it's in units of the type's size
        @count = @fields[:length]
        @data_size = @count * TYPES[@type][:size]

        fix_short_strings
        return if data_fits?

        fetch_long_data
        fix_special_data
      end
    end
  end
end
