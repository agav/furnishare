#------------------------------------------------------------------------------
# All classes to do with the browser based menus and displaying of the cutlist and layout results
# in a browser window
#-----------------------------------------------------------------------------
module Agav
  module Furnishare

    #-----------------------------------------------------------------------------
    # Gui base class to define some common things on all the GUIs
    #-----------------------------------------------------------------------------
    class UiBase
      def initialize(model_name)
        @model_name = model_name
      end

      #base title used for all html pages - to indicate the version of cutlist being used.
      @@title = "Furnishare " + Furnishare.version

      @@furnishare_ui_location = '/furnishare.html'

      @@furnishare_result_location = '/furnishare_result.html'

      def getVersionHtmlTitle
        return @@title
      end

      def getUiHtmlLocation
        return @@furnishare_ui_location
      end

      def getResultHtmlLocation
        return @@furnishare_result_location
      end

      def show(results)
        @results = results
        openDialog
        addCallbacks
        display
        return nil
      end

    end

    #-----------------------------------------------------------------------------
    # class WebGui - for user to select the options and run the script from an html page
    # This dialog is what is displayed when the user first clicks on the plugin
    # and is where we define the callback procedure for the html page to call to
    # pass back and parse the selected parameters
    #-----------------------------------------------------------------------------
    class HtmlGui < UiBase

      def openDialog
        @dialog = UI::HtmlDialog.new(
            :dialog_title => getVersionHtmlTitle,
            :preferences_key => "ua.com.agav",
            :scrollable => true,
            :resizable => true,
            :width => 750,
            :height => 800,
            :left => 230,
            :top => 150,
            :min_width => 50,
            :min_height => 50,
            :max_width => 1000,
            :max_height => 1000,
            :style => UI::HtmlDialog::STYLE_DIALOG)

        @dialog.set_file(File.dirname(__FILE__) + getUiHtmlLocation)
      end

      def addCallbacks
        @dialog.add_action_callback("handleRun") { |d, parameters_json_string|
          parse_input_string(parameters_json_string)
          reporter = Reporter.new
          reporter.sketchupInit(@furnishare_options)
        }
        @dialog.add_action_callback("handleClose") { |d, p|
          @dialog.close()
        }
        @dialog.add_action_callback("handleSaveConfig") { |d, p|
          Sketchup::write_default("furnishare", "settings", p.inspect[1...-1])
        }
        @dialog.add_action_callback("handlePullConfig") { |d, p|
          settings = Sketchup::read_default("furnishare", "settings")
          if settings != nil
            js = "saveConfig(#{settings.inspect})"
          else
            js = "saveConfig({})"
          end
          @dialog.execute_script(js)
        }
      end

      def display
        @dialog.show {}
      end

      def start
        @results = ""
        show(@results)
        return nil
      end

      def parse_input_string(options_json_string)
        @furnishare_options = JSON.parse(options_json_string)
      end


    end

    class ResultGui < UiBase

      def openDialog
        @windowTitle = getVersionHtmlTitle + " - part list " + @model_name
        @resDialog = UI::HtmlDialog.new(
            :dialog_title => @windowTitle,
            :preferences_key => "ua.com.agav.results",
            :scrollable => true,
            :resizable => true,
            :width => 1000,
            :height => 850,
            :left => 250,
            :top => 150,
            :min_width => 50,
            :min_height => 50,
            :max_width => 1000,
            :max_height => 1000,
            :style => UI::HtmlDialog::STYLE_DIALOG)

        @resDialog.set_file(File.dirname(__FILE__) + getResultHtmlLocation)
      end

      def addCallbacks
        @resDialog.add_action_callback("handleClose") { |d, p| @resDialog.close() }
        @resDialog.add_action_callback("handleDocumentLoaded") { |d, p| @resDialog.execute_script("handleResults('#{@results}');") }

        @resDialog.set_on_closed{
          @resDialog.execute_script("handleResults('No results');");
        }
      end

      def display
        @resDialog.show
      end

    end

  end # module CutList
end # module Agav

