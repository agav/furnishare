require 'sketchup'
require 'extensions'
require 'agav_cutlist/utils'

module Agav
	module Furnishare
		@furnishare_extension = SketchupExtension.new "Agav cutlist",
																									"agav_cutlist/FurnishareAndMaterials.rb"

		@furnishare_extension.description = Furnishare.short_description
		@furnishare_extension.version = Furnishare.version
		@furnishare_extension.copyright = Furnishare.year
		@furnishare_extension.creator = Furnishare.author
		Sketchup.register_extension @furnishare_extension, true
	end
end
