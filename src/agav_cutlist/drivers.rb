module Agav
  module Furnishare
    #-----------------------------------------------------------------------------
    # base class for all output generator types, html, or file
    # This class is used to drive the different output parts ie: determine what needs to be
    # output and use the appropriate renderers to produce the output
    #-----------------------------------------------------------------------------
    class OutputDriver
      def initialize(solid_parts, sheet_parts, hardware_parts, model_name)
        @solid_parts = solid_parts
        @sheet_parts = sheet_parts
        @hardware_parts = hardware_parts
        @model_name = model_name
      end

      # open any files required, select a renderer
      def openFiles
        @renderer = nil
      end

      def openRenderer
      end

      def openParts

        return if (@renderer == nil)

        @componentDisplay = CompactDisplay.new(@renderer)

        @sheetDisplay = CompactDisplaySheet.new(@renderer)

        @partDisplay = CompactDisplayPart.new(@renderer)

      end

      # steps required to produce the requested output
      def run
        openFiles
        openRenderer
        openParts
        render
        close
      end

      def render
      end

      def displayResults
      end

      def close
        displayResults
      end
    end

    #-----------------------------------------------------------------------------
    # output driver for all html based output
    #-----------------------------------------------------------------------------
    class HtmlOutputDriver < OutputDriver
      def openFiles
        @html = ""
      end

      def openRenderer
        @renderer = HtmlRenderer.new(@model_name)
      end

      def render
        @html += @renderer.pageHeading("Project: " + @model_name.to_s)
        if (!@solid_parts.empty?)
          @html += @componentDisplay.to_s(@solid_parts.getList)
        end
        if (!@sheet_parts.empty?)
          @html += @sheetDisplay.to_s(@sheet_parts.getList)
        end
        if (!@hardware_parts.empty?)
          @html += @partDisplay.to_s(@hardware_parts)
        end
      end

      def displayResults
        @result_gui = ResultGui.new(@model_name)
        @result_gui.show(@html)
      end
    end

  end
end

