require 'tiff_parser/ifd/ifd_record_headers'

class TIFFParser
  class IFD
    # A record within an IFD (e.g. ImageWidth, ImageHeight)
    class IFDRecord
      attr_accessor :tag, :type, :length, :data

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
        "Length (bytes): #{length}\n" \
        "Data: #{data}\n"
      end

      private

      # if the data is <= 4 bytes, it'll be stored in the field.
      # otherwise, those 4 bytes are the offset of data.
      def data_fits?
        @length <= @data_field_size
      end

      def fix_short_strings
        return unless data_fits? && @type == 2
        @data = PackTheBin.convert(@data,
                                   { type: :uint, size: 4 },
                                   { type: :str, size: '*' }).first
      end

      def fetch_long_data
        custom_field = [{ name: :data, offset: 0, length: @length,
                          type: TYPES[@type][:data_type] }]
        @data = @file.read_fields(custom_field, @data)[:data]
      end

      # some of the data needs to be re-processed after it's brought in
      # (e.g. type 5 is rational, so take uint64 and turn it into uint32 * 2)
      def fix_special_data
        @data = case @type
                when 5 # unsigned rational (see TYPES hash above)
                  PackTheBin.convert(@data,
                                     { type: :uint, size: 8 },
                                     { type: :uint, size: 4, count: 2 })
                when 10 # signed rational (see TYPES hash above)
                  PackTheBin.convert(@data,
                                     { type: :int, size: 8 },
                                     { type: :int, size: 4, count: 2 })
                else
                  @data
                end
      end

      def read_self
        @fields = @file.read_fields(IFD_RECORD, @offset)
        @fields.each { |k, v| instance_variable_set("@#{k}", v) }
        # special case for length because it's in units of the type's size
        @length = @fields[:length] * TYPES[@type][:size]

        fix_short_strings
        return if data_fits?

        fetch_long_data
        fix_special_data
      end
    end
  end
end
