require 'tiff_parser/ifd'
require 'pack_the_bin'

# Parse a tiff file to access the EXIF data stored in it.
class TIFFParser
  FILE_HEADER = [
    { name: :endian, offset: 0, length: 2, type: :str },
    { name: :version, offset: 2, length: 2, type: :uint },
    { name: :img_dir_offset, offset: 4, length: 4, type: :uint }
  ].freeze

  CAMERA_FIELDS = [:BodySerialNumber, :CameraOwnerName,
                   :CameraSerialNumber, :Make, :Model].freeze

  LENS_FIELDS = [:LensModel, :LensSerialNumber, :LensSpecification].freeze

  IMAGE_FIELDS = [:ApertureValue, :Artist, :Copyright, :DateTime,
                  :ExposureMode, :ExposureTime, :Flash, :FNumber,
                  :FocalLength, :ImageDescription, :ImageHeight,
                  :ImageWidth, :ISOSpeedRatings, :MeteringMode,
                  :SceneCaptureType, :SelfTimeMode, :ShutterSpeedValue,
                  :Software, :SubjectDistanceRange, :WhiteBalance,
                  :FocalPlaneXResolution, :FocalPlaneYResolution].freeze

  # fields that hold an offset to yet another IFD
  REFERENCED_IFDS = [:ExifIFD, :GPSInfo, :SubIFDs].freeze

  def initialize(file_path)
    @path = file_path
    @file = PackTheBin.new(@path)
    @ifds = []
    load_image_file_dirs
  end

  def file_header_fields
    @file.read_fields(FILE_HEADER)
  end

  def all_ifd_records
    @ifds.map(&:records).flatten
  end

  # TODO: need to be careful with ImageHeight and ImageWidth since there may
  # be multiple instances of it (across IFDs). I'm assuming this has something
  # to do with embedded jpeg previews.
  def interesting_records
    ret = {}
    all_recs = all_ifd_records
    ret[:camera] = all_recs.select { |r| CAMERA_FIELDS.include? r.tag_name }
    ret[:image] = all_recs.select { |r| IMAGE_FIELDS.include? r.tag_name }
    ret[:lens] = all_recs.select { |r| LENS_FIELDS.include? r.tag_name }
    ret
  end

  private

  def load_image_file_dirs
    # load first IFD, stored at specified offset
    ifd_offset = file_header_fields[:img_dir_offset]
    loop do
      ifd = IFD.new(@file, ifd_offset)
      ifd_offset = ifd.next_offset
      @ifds << ifd
      break if ifd_offset.zero?
    end

    load_referenced_ifds
  end

  def load_referenced_ifds
    recs = all_ifd_records.select { |r| REFERENCED_IFDS.include? r.tag_name }
    recs.each { |rec| @ifds << IFD.new(@file, rec.data) }
  end
end
