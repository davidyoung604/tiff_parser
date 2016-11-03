class TIFFParser
  class IFD
    # Headers for IFD Records. Kept separate to keep the class cleaner.
    module IFDRecordHeaders
      IFD_RECORD = [
        { name: :tag, offset: 0, length: 2, type: :uint },
        { name: :type, offset: 2, length: 2, type: :uint },
        { name: :length, offset: 4, length: 4, type: :uint },
        { name: :data, offset: 8, length: 4, type: :uint }
      ].freeze

      TYPES = {
        1 => { size: 1, data_type: :byte }, # byte
        2 => { size: 1, data_type: :str }, # ascii char
        3 => { size: 2, data_type: :uint }, # short (uint16)
        4 => { size: 4, data_type: :uint }, # long (uint32)
        5 => { size: 8, data_type: :uint }, # rational (long/long)
        6 => { size: 1, data_type: :int }, # signed byte (int8)
        7 => { size: 1, data_type: :str }, # sony. spec lists "undefined"
        8 => { size: 2, data_type: :int }, # signed short (int16)
        9 => { size: 4, data_type: :int }, # signed long (int32)
        10 => { size: 8, data_type: :int }, # nikon. signed rational (long/long)
        11 => { size: 4, data_type: :float }, # single-precision float
        12 => { size: 8, data_type: :double }, # double-precision float
      }.freeze

      TAGS = {
        254 => { name: :NewSubfileType },
        255 => { name: :SubfileType },
        256 => { name: :ImageWidth },
        257 => { name: :ImageHeight },
        258 => { name: :BitsPerSample },
        259 => { name: :Compression },
        262 => { name: :PhotometricInterpretation },
        270 => { name: :ImageDescription }, # string
        271 => { name: :Make }, # e.g. Canon
        272 => { name: :Model }, # e.g. Canon 5D Mark III
        273 => { name: :StripOffsets },
        274 => { name: :Orientation },
        277 => { name: :SamplesPerPixel },
        278 => { name: :RowsPerStrip },
        279 => { name: :StripByteCounts },
        282 => { name: :XResolution }, # e.g. for PPI
        283 => { name: :YResolution }, # e.g. for PPI
        284 => { name: :PlanarConfiguration },
        # ResolutionUnit e.g. "Inch" for PPI. 1 = none, 2 = inch, 3 = cm
        296 => { name: :ResolutionUnit },
        305 => { name: :Software },
        306 => { name: :DateTime },
        315 => { name: :Artist },
        330 => { name: :SubIFDs }, # offset to child IFDs
        513 => { name: :JPEGInterchangeFormat },
        532 => { name: :ReferenceBlackWhite },
        514 => { name: :JPEGInterchangeFormatLength },
        531 => { name: :YCbCrPositioning },
        700 => { name: :XMP }, # stored in XML format. reinterpret as string
        33_432 => { name: :Copyright },
        33_434 => { name: :ExposureTime }, # in seconds
        33_437 => { name: :FNumber }, # f-stop
        34_665 => { name: :ExifIFD }, # pointer to exif IFD
        34_850 => { name: :ExposureProgram },
        34_853 => { name: :GPSInfo }, # pointer to gps-info IFD?
        34_855 => { name: :ISOSpeedRatings },
        34_859 => { name: :SelfTimeMode }, # seconds of delay
        34_864 => { name: :SensitivityType },
        34_866 => { name: :RecommendedExposureIndex }, # == ISOSpeedRatings?
        36_864 => { name: :ExifVersion },
        36_867 => { name: :DateTimeOriginal },
        36_868 => { name: :DateTimeDigitized },
        37_121 => { name: :ComponentsConfiguration },
        37_122 => { name: :CompressedBitsPerPixel },
        37_377 => { name: :ShutterSpeedValue },
        37_378 => { name: :ApertureValue },
        37_379 => { name: :BrightnessValue },
        37_380 => { name: :ExposureBiasValue },
        37_381 => { name: :MaxApertureValue },
        37_383 => { name: :MeteringMode },
        37_384 => { name: :LightSource },
        37_385 => { name: :Flash },
        37_386 => { name: :FocalLength }, # in mm
        37_390 => { name: :FocalPlaneXResolution },
        37_391 => { name: :FocalPlaneYResolution },
        37_392 => { name: :FocalPlaneResolutionUnit },
        37_398 => { name: :TIFFStandardID }, # TIFF/EPStandardID
        37_500 => { name: :MakerNote }, # mfgr-specific info
        # UserComment: keywords/comments. complements ImageDescription
        37_510 => { name: :UserComment },
        37_520 => { name: :SubsecTime }, # fractions of a sec for DateTime
        37_521 => { name: :SubsecTimeOriginal },
        37_522 => { name: :SubsecTimeDigitized },
        40_960 => { name: :FlashpixVersion },
        40_961 => { name: :ColorSpace },
        40_962 => { name: :PixelXDimension },
        40_963 => { name: :PixelYDimension },
        40_965 => { name: :InteroperabilityIFD },
        41_486 => { name: :FocalPlaneXResolution }, # exif
        41_487 => { name: :FocalPlaneYResolution }, # exif
        41_488 => { name: :FocalPlaneResolutionUnit }, # exif
        41_495 => { name: :SensingMethod },
        41_728 => { name: :FileSource },
        41_729 => { name: :SceneType },
        41_730 => { name: :CFAPattern },
        41_985 => { name: :CustomRendered },
        41_986 => { name: :ExposureMode },
        41_987 => { name: :WhiteBalance },
        41_988 => { name: :DigitalZoomRatio },
        41_989 => { name: :FocalLengthIn35mmFilm }, # in mm, I suppose?
        41_990 => { name: :SceneCaptureType },
        41_991 => { name: :GainControl },
        41_992 => { name: :Contrast },
        41_993 => { name: :Saturation },
        41_994 => { name: :Sharpness },
        41_996 => { name: :SubjectDistanceRange },
        42_016 => { name: :ImageUniqueID },
        42_032 => { name: :CameraOwnerName },
        42_033 => { name: :BodySerialNumber }, # SN of the camera body
        # LensSpecification: "This tag notes minimum focal length, maximum focal
        # length, minimum F number in the minimum focal length, and minimum F
        # number in the maximum focal length, which are specification info
        # for the lens that was used in photography. When the minimum F number
        # is unknown, the notation is 0/0." TODO: Unsure of what that all means.
        42_034 => { name: :LensSpecification },
        42_036 => { name: :LensModel },
        42_037 => { name: :LensSerialNumber },
        50_341 => { name: :PrintImageMatching },
        50_706 => { name: :DNGVersion },
        50_708 => { name: :UniqueCameraModel },
        50_721 => { name: :ColorMatrix1 },
        50_722 => { name: :ColorMatrix2 },
        50_723 => { name: :CameraCalibration1 },
        50_724 => { name: :CameraCalibration2 },
        50_728 => { name: :AsShotNeutral },
        50_730 => { name: :BaselineExposure },
        50_731 => { name: :BaselineNoise },
        50_732 => { name: :BaselineSharpness },
        50_734 => { name: :LinearResponseLimit },
        50_735 => { name: :CameraSerialNumber },
        50_740 => { name: :DNGPrivateData },
        50_741 => { name: :MakerNoteSafety },
        50_778 => { name: :CalibrationIlluminant1 },
        50_779 => { name: :CalibrationIlluminant2 },
        50_781 => { name: :RawDataUniqueID }
      }.freeze
    end
  end
end
