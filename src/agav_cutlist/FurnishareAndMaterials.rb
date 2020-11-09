require 'sketchup'
require 'agav_cutlist/reporter'  # the gui classes to bring up the main menu

module Agav
	module Furnishare
	
# 		create a GUI instance that prompts for an interactive configuration, producing the requested output formats
# 		This is the main menu invoked when the user selects the Cut List plugin menu item
		def Furnishare.furnishare_interactive_menu
			furnishare_webGui = HtmlGui.new("Furnishare")
			furnishare_webGui.start
		end

# 		Add the plugin command to the Plugins menu
# 		Add CutList main entry 
# 		"Cut List" offers an html gui to select options and produce html and/or file output 
		unless file_loaded?( __FILE__ ) 
			plugins_menu = UI.menu("Plugins")
  
			plugins_menu.add_item("Furnishare") { Furnishare.furnishare_interactive_menu }
		end 

		file_loaded( __FILE__ )
	end
end
#-----------------------------------------------------------------------------





