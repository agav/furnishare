module Agav
  module Furnishare

    #require 'agav_cutlist/debug.rb'
    #Agav::Furnishare.reload

    def self.reload(return_files = false)
      original_verbose = $VERBOSE
      $VERBOSE = nil
      x = Dir.glob(File.join(__dir__, '*.{rb,rbs}')).each { |file|
        load file
      }
      (return_files) ? x : x.length
    ensure
      $VERBOSE = original_verbose
    end
  end
end