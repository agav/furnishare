require 'sketchup'
require 'extensions'
require 'agav_cutlist/cutlistutl'

module Agav
	module AgavCutList
		@su_cutlist_extension = SketchupExtension.new "Agav cutlist",
		"agav_cutlist/CutListAndMaterials.rb"

		@su_cutlist_extension.description = AgavCutList.short_description
		@su_cutlist_extension.version = AgavCutList.version
		@su_cutlist_extension.copyright = AgavCutList.year
		@su_cutlist_extension.creator = AgavCutList.author
		Sketchup.register_extension @su_cutlist_extension, true
	end
end
