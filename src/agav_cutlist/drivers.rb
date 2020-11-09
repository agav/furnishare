module Agav
  module Furnishare
    #-----------------------------------------------------------------------------
    # base class for all output generator types, html, or file
    # This class is used to drive the different output parts ie: determine what needs to be
    # output and use the appropriate renderers to produce the output
    #-----------------------------------------------------------------------------
    class OutputDriver
      def initialize(compact, showComps, showSheet, showParts, volumeInMetric, solidParts, sheetParts, hardwareParts, mname)
        @compact = compact
        @showComps = showComps
        @showSheet = showSheet
        @showParts = showParts
        @showVolumeInMetric = volumeInMetric
        @solidParts = solidParts
        @sheetParts = sheetParts
        @hardwareParts = hardwareParts
        @modelName = mname
      end

      # open any files required, select a renderer
      def openFiles
        @renderer = nil
      end

      def openRenderer
      end

      # perform necessary rendering to produce requested output format
      def openParts
        return if (@renderer == nil)

        if (@showComps)
          if (@compact)
            @component = CompactDisplay.new(@renderer, @showVolumeInMetric)
            #	compact list is sorted by component names
            @solidParts.sortByName
            puts "OutputDriver::openParts - Sorting solid parts by name"
          else
            @component = Display.new(@renderer, @showVolumeInMetric)
          end
        end # showComps

        if (@showSheet)
          if (@compact)
            @sheet = CompactDisplaySheet.new(@renderer, @showVolumeInMetric)
            #	compact list is sorted by component names
            @sheetParts.sortByName
            puts "OutputDriver::openParts - Sorting sheet parts by name"
          else
            @sheet = DisplaySheet.new(@renderer, @showVolumeInMetric)
          end
        end # showSheet

        if @showParts
          @part = CompactDisplayPart.new(@renderer, @showVolumeInMetric)
        end

      end

      # openParts

      # steps required to produce the requested output
      def run
        openFiles
        openRenderer
        openParts
        render
        close
      end

      # close any files which are open
      def closeFiles
      end

      # display results of the rendering, either 'output done' msg or display the file
      def displayResults
      end

      # steps after rendering is complete
      def close
        closeFiles
        displayResults
      end
    end

    #-----------------------------------------------------------------------------
    # output driver for all file based output
    #-----------------------------------------------------------------------------
    class FileOutputDriver < OutputDriver
      def initialize(compact, showComps, showSheet, showParts, volumeInMetric, solidParts, sheetParts, hardwareParts, mname, mpath, filename)
        super(compact, showComps, showSheet, showParts, volumeInMetric, solidParts, sheetParts, hardwareParts, mname)
        @model_path = mpath
        @filename = filename
        @modelName = mname
      end

      def openFiles
        @namecsv = @model_path + "/" + @modelName + "_" + @filename
        @file = File.new(@namecsv, "w")
      end

      def openRenderer
        @renderer = FileRenderer.new(@modelName)
      end

      def render
        if (@showComps && !@solidParts.empty?)
          @file.puts(@component.to_s(@solidParts.getList))
        end
        if (@showSheet && !@sheetParts.empty?)
          @file.puts(@sheet.to_s(@sheetParts.getList))
        end
        if (@showParts && !@hardwareParts.empty?)
          @file.puts(@part.to_s(@hardwareParts))
        end
      end

      def closeFiles
        @file.close
      end

      def displayResults
        UI.messagebox("Cut List written into: \n\n" + @namecsv + "  \n")
      end

    end

    #-----------------------------------------------------------------------------
    # output driver for cutlist plus output - a file based csv
    #-----------------------------------------------------------------------------
    class ClpFileOutputDriver < FileOutputDriver
      # perform necessary rendering to produce requested output format
      def openParts
        return if (@renderer == nil)

        if (@showComps)
          if (@compact)
            @component = CompactClpDisplay.new(@renderer, @showVolumeInMetric)
            @solidParts.sortByName
            puts "ClpFileOutputDriver::openParts - Solid parts - sorting by name"
          else
            @component = ClpDisplay.new(@renderer, @showVolumeInMetric)
          end
        end # showComps

        if (@showSheet)
          if (@compact)
            @sheet = CompactClpDisplaySheet.new(@renderer, @showVolumeInMetric)
            @sheetParts.sortByName
            puts "ClpFileOutputDriver::openParts - Sheet parts - sorting by name"
          else
            @sheet = ClpDisplaySheet.new(@renderer, @showVolumeInMetric)
          end
        end # showSheet

        # Add parts to CLP csv file
        if @showParts
          @part = CompactClpDisplayPart.new(@renderer, @showVolumeInMetric)
        end
      end

      def displayResults
        UI.messagebox("Cut List Plus import file written into: \n\n" + @namecsv + "  \n")
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
        @renderer = HtmlRenderer.new(@modelName)
      end

      def startPage
        #    @html += @renderer.header(@x,@y)
        pageHeading = "Project: " + @modelName.to_s
        @html += @renderer.pageHeading(pageHeading)
        #    pageYIncrement(30)
      end

      def render
        startPage
        if (@showComps && !@solidParts.empty?)
          @html += @component.to_s(@solidParts.getList)
        end
        if (@showSheet && !@sheetParts.empty?)
          @html += @sheet.to_s(@sheetParts.getList)
        end
        if (@showParts && !@hardwareParts.empty?)
          @html += @part.to_s(@hardwareParts)
        end
      end

      # an opportunity to do something whenever y coordinate reaches a certain value
      # default is to only increment the y coordinate
      def pageYIncrement(yIncrement)
        @y += yIncrement
      end

      # no files to close
      def closeFiles
      end

      def displayResults
        @resultGui = ResultGui.new(@modelName)
        @resultGui.show(@html)
      end
    end

  end # module CutList
end # module Agav

