#------------------------------------------------------------------------------
# All classes to do with the browser based menus and displaying of the cutlist and layout results
# in a browser window
#-----------------------------------------------------------------------------
module Agav
  module Furnishare

    #-----------------------------------------------------------------------------
    # Gui base class to define some common things on all the GUIs
    #-----------------------------------------------------------------------------
    class GuiBase
      def initialize(mname)
        @modelName = mname
      end

      #base title used for all html pages - to indicate the version of cutlist being used.
      @@title = "Cut List " + Furnishare.version

      # relative location of the cutlist input html page
      @@furnishare_ui_location = '/cutlistui.html'

      #relative location of the cutlist result html template
      @@furnishare_result_location = '/cutlistresult.html'

      def getVersionHtmlTitle
        return @@title
      end

      def getProjectLabelPrefix
        return " for Project: "
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

      ##ResultGui.displayResults

    end

    #-----------------------------------------------------------------------------
    # class WebGui - for user to select the options and run the script from an html page
    # This dialog is what is displayed when the user first clicks on the plugin
    # and is where we define the callback procedure for the html page to call to
    # pass back and parse the selected parameters
    #-----------------------------------------------------------------------------
    class WebGui < GuiBase
      def openDialog
        @dialog = UI::WebDialog.new(getVersionHtmlTitle, true, nil, 750, 800, 230, 150, true)
        #    @dlg.set_position(150,150)
        #    @dlg.set_size(600,550)
        @dialog.set_file(File.dirname(__FILE__) + getUiHtmlLocation)
      end

      def addCallbacks
        @dialog.add_action_callback("handleRun") { |d, p|
          # DEBUG - print selected input parameters from dialog
          puts p
          parse_input_string(p)
          reporter = Reporter.new
          reporter.sketchupInit(@partlist_options, @layout_options)
        }
        @dialog.add_action_callback("handleClose") { |d, p|
          @dialog.close()
        }
        # Note this callback is not actually used as part of the normal
        # processing but is available in case the parameters wish to be
        # saved to a file.
        # Selected parameters are saved in the html by creating a cookie and writing that
        # to the browser cookie location. The file created here is not used and there
        # is currently nothing in the html to invoke this callback.
        @dialog.add_action_callback("handleSaveConfig") { |d, p|
          parse_input_string(p)
          stdout = $stdout
          File.open(File.dirname(__FILE__) + getConfigLocation, File::CREAT | File::WRONLY) do |f|
            f.puts p.to_s
            f.puts @partlist_options.inspect
            f.puts @layout_options.inspect
          end
          $stdout = stdout
          puts "Saved to " + File.dirname(__FILE__) + getConfigLocation if Furnishare.verbose1
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

      # start

      def calcNominalMargin(nominalMarginStr)
        nominalMargin = Float(nominalMarginStr)
        return nominalMargin.inch / 16
      end

      def calcKerfSize(kerfSizeStr, kerfSizeUnits)
        if kerfSizeStr == ""
          return 0
        end
        kerfSize = Float(kerfSizeStr)
        if kerfSize == 0
          return 0
        end
        if (kerfSizeUnits == "32nd")
          return (kerfSize / 32).inch
        elsif (kerfSizeUnits == "16th")
          return (kerfSize / 16).inch
        elsif (kerfSizeUnits == "8th")
          return (kerfSize / 8).inch
        elsif (kerfSizeUnits == "4th")
          return (kerfSize / 4).inch
        elsif (kerfSizeUnits == "mm")
          return Furnishare::float_round_to(4, Float(kerfSize / 25.4)).inch
        else
          return 0
        end
      end

      def parse_input_string(params_json_string)
        # display the parameters as they are sent from the html page
        puts "input parameter array: <<<<<" + params_json_string.to_s if Furnishare.verboseParameters

        params_hash = JSON.parse(params_json_string)

        a = params_json_string.split(',')
        parse_input_array(params_hash)
        @partlist_options = getCutlistOptions(a)
        # display the cutlist options after they are parsed from the input parameters
        puts "cutlist options parsed: <<<<<" + @partlist_options.to_s if Furnishare.verboseParameters
        @layout_options = getLayoutOptions(a)
        # display the layout options after they are parsed from the input parameters
        puts "layout options parsed: <<<<<" + @layout_options.to_s if Furnishare.verboseParameters
      end

      def parse_input_array(hash)
        @compactList = hash[:compactList]
        @nominalOut = hash[:nominalOut]
        @linearFeet = hash[:linearFeet]
        @outFileUsed = hash[:outFileUsed]
        @outFileName = hash[:outFileName]
        @clpFileUsed = hash[:clpFileUsed]
        @clpFileName = hash[:clpFileName]
        @printPage = hash[:printPage]
        @partWords = hash[:partWords]
        @sheetWords = hash[:sheetWords]
        @comps = hash[:comps]
        @sheet = hash[:sheet]
        @parts = hash[:parts]
        @forceBoardFeet = hash[:forceBoardFeet]
        @fourq = hash[:fourq]
        @fiveq = hash[:fiveq]
        @sixq = hash[:sixq]
        @eightq = hash[:eightq]
        @tenq = hash[:tenq]
        @nominalMargin = hash[:nominalMargin]
        @layout = hash[:layout]
        @boardWidthOption = hash[:boardWidthOption]
        @boardLengthOption = hash[:boardLengthOption]
        @sheetWidthOption = hash[:sheetWidthOption]
        @sheetLengthOption = hash[:sheetLengthOption]
        @nominalWidth = hash[:nominalWidth]
        @kerfSize = hash[:kerfSize] # obsolete, use sawKerfSize,kerfSizes
        @splitWideParts = hash[:splitWideParts]
        @splitThickParts = hash[:splitThickParts]
        @layoutRuleA = hash[:layoutRuleA]
        @layoutRuleB = hash[:layoutRuleB]
        @layoutByMaterial = hash[:layoutByMaterial]
        @displayUnplacedParts = hash[:displayUnplacedParts]
        @svgLayout = hash[:svgLayout]
        @useSawKerf = hash[:useSawKerf]
        @sawKerfSize = hash[:sawKerfSize]
        @sawKerfUnits = hash[:sawKerfUnits]
      end

      def getCutlistOptions(a)
        cutlist_options = {
            :compactList => (@compactList == "compactList"),
            :listAllSorted => (@compactList == "listAllSorted"),
            :linearFeet => (@linearFeet == "true"),
            :outFileUsed => (@outFileUsed == "true"),
            :clpFileUsed => (@clpFileUsed == "true"),
            :printPage => (@printPage == "true"),
            :showComps => (@comps == "true"),
            :showSheet => (@sheet == "true"),
            :showParts => (@parts == "true"),
            :forceBoardFeet => (@forceBoardFeet == "true"),
            :layout => (@layout == "true"),
            :partWords => @partWords.split(' '),
            :sheetWords => @sheetWords.split(' '),
            :svgLayout => (@svgLayout == "true")
        }

        # include file names only if not nil
        if @outFileName != ""
          cutlist_options[:outFileName] = @outFileName
        end

        if @clpFileName != ""
          cutlist_options[:clpFileName] = @clpFileName
        end

        return cutlist_options
      end

      def getLayoutOptions(a)
        layout_options = {
            :fourq => (@fourq == "true"),
            :fiveq => (@fiveq == "true"),
            :sixq => (@sixq == "true"),
            :eightq => (@eightq == "true"),
            :tenq => (@tenq == "true"),
            :nominalMargin => calcNominalMargin(@nominalMargin),
            :nominalOut => (@nominalOut == "true"),
            :board4w => (@boardWidthOption == "board4w"),
            :board6w => (@boardWidthOption == "board6w"),
            :board8w => (@boardWidthOption == "board8w"),
            :board10w => (@boardWidthOption == "board10w"),
            :board12w => (@boardWidthOption == "board12w"),
            :board2l => (@boardLengthOption == "board2l"),
            :board4l => (@boardLengthOption == "board4l"),
            :board6l => (@boardLengthOption == "board6l"),
            :board8l => (@boardLengthOption == "board8l"),
            :board10l => (@boardLengthOption == "board10l"),
            :board12l => (@boardLengthOption == "board12l"),
            :sheet2w => (@sheetWidthOption == "sheet2w"),
            :sheet4w => (@sheetWidthOption == "sheet4w"),
            :sheet5w => (@sheetWidthOption == "sheet5w"),
            :sheet2l => (@sheetLengthOption == "sheet2l"),
            :sheet4l => (@sheetLengthOption == "sheet4l"),
            :sheet5l => (@sheetLengthOption == "sheet5l"),
            :sheet8l => (@sheetLengthOption == "sheet8l"),
            :nominalWidth => (@nominalWidth == "false"),
            :kerfSize => @kerfSize,
            :splitWideParts => (@splitWideParts == "true"),
            :splitThickParts => (@splitThickParts == "true"),
            :layoutRuleA => (@layoutRuleA == "true"),
            :layoutRuleB => (@layoutRuleB == "true"),
            :layoutByMaterial => (@layoutByMaterial == "true"),
            :displayUnplacedParts => (@displayUnplacedParts == "true"),
            :useSawKerf => (@useSawKerf == "true"),
            :sawKerfSize => (calcKerfSize(@sawKerfSize, @sawKerfUnits)),
            :sawKerfUnits => @sawKerfUnits
        }
        return layout_options
      end

    end

    ## WebGui class

    # class ResultGui - for the output of the user selection when html output has been selected
    # Cutlist display uses this class
    class ResultGui < GuiBase

      def openDialog
        @cutlistWindowTitle = getVersionHtmlTitle + " - " + " Cutlist" + getProjectLabelPrefix + @modelName
        @resDialog = UI::WebDialog.new(@cutlistWindowTitle, true, nil, 1000, 850, 250, 150, true)
        @resDialog.set_file(File.dirname(__FILE__) + getResultHtmlLocation)
        #@resDialog.set_position(150,150)
      end

      def addCallbacks
        @resDialog.add_action_callback("handleClose") { |d, p| @resDialog.close() }
        @resDialog.set_on_close {
          @resDialog.execute_script("handleResults('No results');");
        }
      end

      def display
        @resDialog.show {
          @resDialog.execute_script("handleResults(\'#{@results}\');");
        }
      end

    end

    ## ResultGui class

    # class LayoutGui - for the output of the layout when html output has been selected
    # based on ResultGui but the position is offset, so that if both output types are
    # requested, they dopn't end up displaying on top of each other.
    class LayoutGui < ResultGui

      def openDialog
        @layoutWindowTitle = getVersionHtmlTitle + " - " + "Layout" + getProjectLabelPrefix + @modelName
        @resDialog = UI::WebDialog.new(@layoutWindowTitle, true, nil, 1000, 900, 300, 150, true)
        @resDialog.set_file(File.dirname(__FILE__) + getResultHtmlLocation)
        #@resDialog.set_position(200,200)
      end

      def addCallbacks
        @resDialog.add_action_callback("handleClose") { |d, p| @resDialog.close() }
      end

      def display
        #   debug
        #puts @results
        @resDialog.show {
          @resDialog.execute_script("handleLayoutScript(\'#{@results}\');");
        }
      end

    end

    # layoutGui class

  end # module CutList
end # module Agav

