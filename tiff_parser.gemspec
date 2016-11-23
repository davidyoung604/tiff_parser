Gem::Specification.new do |s|
  s.name        = 'tiff_parser'
  s.version     = '0.0.1'
  s.date        = '2016-10-27'
  s.summary     = 'Parse TIFF files (for EXIF data)'
  s.description = 'Reads the EXIF data stored in a TIFF file, including ' \
                  'CR2, NEF, ARW, DNG files.'
  s.authors     = ['David Young']
  s.files       = Dir['lib/**/*.rb', 'LICENCE', '*.md']
  s.license     = 'Nonstandard'
  s.homepage    = 'https://github.com/davidyoung604/tiff_parser'
end
