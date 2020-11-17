module Agav
  module Furnishare
    #########################
    # Display_class superclass      #
    #########################
    class Display_class

      def initialize(inRenderer)
        @renderer = inRenderer
        @metric = true
        @roundToNumOfDigits = 2
        @roundToNumOfDigits = 4 if (@metric)
      end

      ## end initialize

      def getTitle(title)
        return @renderer.getTitle(title)
      end

      ## end getTitle

      def getHeaderRow(headers)
        return @renderer.getHeaderRow(headers)
      end

      ## end getHeaderRow

      def getFooterRow()
        return @renderer.getFooterRow()
      end

      ## end getFooterRow

      def getRow(columns)
        return @renderer.getRow(columns)
      end

      ## end getRow

      def getAmount(amount)
        return @renderer.getAmount(amount)
      end

      ## end getArea

      def getBlankLine()
        return @renderer.getBlankLine()
      end

      ## end getBlankLine

      def to_s(inList) end

      ## end to_s

    end

    ##Display_class

    #########################
    # Display                                              #
    #########################
    class Display < Display_class

      def initialize(inRenderer)
        super(inRenderer)
        @measureLabel = getMeasureLabel
        @measureUnits = getMeasureUnits
      end

      def getMeasureLabel
        if @metric
          return "Cubic m"
        else
          return "Board Foot"
        end
      end

      def getMeasureUnits
        if @metric
          return "m"
        else
          return "Feet"
        end
      end

      def getPartPrefix()
        return "C-"
      end

      def getTitleName()
        return "Components";
      end

      def getHeadingArray()
        headings = ["Part #", "Sub-Assembly", "Description", "Length(L)", "Width(W)", "Thickness(T)", @measureLabel, "Material"]
        return headings
      end

      def getAmountTitleName()
        return "Total Component " + @measureLabel
      end

      def getMaterialTitleName()
        return "Component Materials"
      end

      def isAmountEnabled()
        return true
      end

      def isMaterialEnabled()
        return true
      end

      def processRows(inList)

        component = ""
        cols = Array.new
        i = 1
        ii = 0
        ix = ""
        cx = ""

        for c in inList
          i = i + 1 if c.getName != cx and cx != ""
          ii = 1 if c.getName != cx
          ix = Furnishare::integer_to_fws(3, i) + "-" + Furnishare::integer_to_fws(2, ii)
          cols[0] = getPartPrefix() + ix
          cols[1] = c.getSubAssemblyName
          cols[2] = c.getName
          cols[3] = c.getLengthString
          cols[4] = c.getWidthString
          cols[5] = c.getThicknessString
          # the next  line is modified specifically for european users who default to an English version
          # of Sketchup - as Sketchup does not seem to convert these numericals to have comma as the decimal
          # When I find a way to automatically discover which way the user needs to have this, then this can
          # be replaced with some external check - or else decimal to comma can return the string
          # unchanged.
          #cols[6]=c.getBoardFeet.to_s
          cols[6] = Furnishare::decimal_to_comma(c.getBoardFeet.to_s)

          cols[7] = c.getMaterial
          component = component + getRow(cols)
          ### gives sub-part numbers to same named compos; last = total
          ii = ii + 1
          cx = c.getName
          ## Add the board feet
          @totalBF = @totalBF + c.getBoardFeet
          inList = false
          for d in @materialList
            if (d[0] == c.getMaterial)
              d[1] = d[1] + c.getBoardFeet
              inList = true
            end ## end if
          end ## end for

          if (!inList)
            @materialList = @materialList.push([c.getMaterial, c.getBoardFeet])
          end

        end ## end for

        return component
      end

      ## end processRows

      def to_s(inList)

        @materialList = []
        @totalBF = 0
        @totalLength = 0
        tempFloat = 0

        component = ""
        component = component + getTitle(getTitleName())
        headings = getHeadingArray()
        component = component + getHeaderRow(headings)
        component = component + processRows(inList)
        component = component + getFooterRow()
        component = component + getBlankLine()

        ## Total Board Feet Table
        if (isAmountEnabled())
          component = component + getTitle(getAmountTitleName())
          cols = Array.new
          tempFloat = Furnishare::float_round_to(@roundToNumOfDigits, @totalBF)
          # the next  line is modified specifically for european users who default to an English version
          # of Sketchup - as Sketchup does not seem to convert these numericals to have comma as the decimal
          # When I find a way to automatically discover which way the user needs to have this, then this can
          # be replaced with some external check - or else decimal to comma can return the string
          # unchanged.
          #cols[0] = tempFloat.to_s
          cols[0] = Furnishare::decimal_to_comma(tempFloat.to_s)
          component = component + getRow(cols)
          component = component + getFooterRow()
          component = component + getBlankLine()
        end

        ## Materials Table
        if (isMaterialEnabled())
          component = component + getTitle(getMaterialTitleName())
          headings = ["Material", @measureLabel]
          component = component + getHeaderRow(headings)
          for d in @materialList
            cols = Array.new
            cols[0] = d[0]
            tempFloat = Furnishare::float_round_to(@roundToNumOfDigits, d[1])
            # the next  line is modified specifically for european users who default to an English version
            # of Sketchup - as Sketchup does not seem to convert these numericals to have comma as the decimal
            # When I find a way to automatically discover which way the user needs to have this, then this can
            # be replaced with some external check - or else decimal to comma can return the string
            # unchanged.
            #cols[1] = tempFloat.to_s
            cols[1] = Furnishare::decimal_to_comma(tempFloat.to_s)
            component = component + getRow(cols)
          end ## end for
          component = component + getFooterRow()
          component = component + getBlankLine()
        end

        return component

      end

      ## end to_s

    end

    ##Display class

    #########################
    # CompactDisplay                                   #
    #########################
    class CompactDisplay < Display

      def getHeadingArray()
        #headings=["Part#","Quantity","Sub-Assembly","Description","Length(L)","Width(W)","Thickness(T)",@measureLabel + " (per)",
        headings = %w[Length(L) Width(W) Quantity U D L R Texture Name Thickness(T) Material]
        return headings
      end

      def processRows(inList)

        component = ""
        partId = 1
        partCount = 1
        #firstPart = ["","",0,0,0,""]
        firstPart = ["", 0, 0, 0, ""]
        lastPart = firstPart
        cols = Array.new
        row = ""

        for c in inList

          # If parts match the name and dimensions and material, then they are considered the
          # same and will be displayed in the compact form
          if (c.getName == lastPart[0]) &&
              #( c.getSubAssemblyName == lastPart[1] ) &&
              (c.getLengthString == lastPart[1]) &&
              (c.getWidthString == lastPart[2]) &&
              (c.getThicknessString == lastPart[3]) &&
              (c.getMaterial == lastPart[4])
            partCount = partCount + 1
          elsif lastPart != firstPart
            component = component + row
            partId = partId + 1
            partCount = 1
          end ##if

          cols[0] = c.getLengthString
          cols[1] = c.getWidthString
          cols[2] = partCount.to_s

          cols[3] = c.up.output_index.to_s
          cols[4] = c.down.output_index.to_s
          cols[5] = c.left.output_index.to_s
          cols[6] = c.right.output_index.to_s


          cols[7] = c.oriented.to_s

          cols[8] = c.getName
          cols[9] = c.getThicknessString

          cols[10] = c.getMaterial
          row = getRow(cols)

          lastPart = [c.getName, c.getLengthString, c.getWidthString, c.getThicknessString, c.getMaterial]

          inList = false
          @materialList.each { |d|
            if (d[0] == c.getMaterial)
              d[1] = d[1] + c.getBoardFeet
              inList = true
            end
          }

          if (!inList)
            @materialList = @materialList.push([c.getMaterial, c.getBoardFeet])
          end

        end

        ##Output last row
        component = component + row

        return component
      end

      ## end processRows


    end

    ##class CompactDisplay

    #-----------------------------------------------------------------------------
    #########################
    # CompactPart           #
    #########################
    class CompactDisplayPart < CompactDisplay

      def getPartPrefix()
        return "P-"
      end

      def getTitleName()
        return "Other Parts";
      end

      def getHeadingArray()
        headings = ["Part #", "Quantity", "Description"]
        return headings
      end

      def getAmountTitleName()
        return ""
      end

      def getMaterialTitleName()
        return ""
      end

      def isAmountEnabled()
        return false
      end

      def isMaterialEnabled()
        return false
      end

      def processRows(inList)

        component = ""
        cols = Array.new

        if (inList.parts.length > 0)
          for e in 0..(inList.parts.length - 1)
            cols[0] = getPartPrefix() + Furnishare::integer_to_fws(3, (e + 1))
            cols[1] = inList.partCount[e].to_s
            cols[2] = inList.parts[e]
            component = component + getRow(cols)
          end ###for
        end ###if
        return component

      end

      ## end processRows


    end

    ## CompactDisplayPart


    #########################
    # CompactDisplaySheet                           #
    #########################
    class CompactDisplaySheet < CompactDisplay

      def getMeasureLabel
        if @metric
          return "Square m"
        else
          return "Square Foot"
        end
      end

      def getPartPrefix()
        return "S-"
      end

      def getHeadingArray()
        headings = ["Part#", "Quantity", "Description", "Length(L)", "Width(W)", "Thickness(T)", @measureLabel + " (per)",
                    @measureLabel + " (total)", "Total Length (" + @measureUnits + ")", "Material"]
        return headings
      end

      def getTitleName()
        return "Sheet Goods";
      end

      def getAmountTitleName()
        return "Total Sheet " + @measureLabel
      end

      def getMaterialTitleName()
        return "Sheet Materials"
      end

    end

    ##class CompactDisplaySheet

    #########################
    # DisplaySheet                                      #
    #########################
    class DisplaySheet < Display

      def getMeasureLabel
        if @metric
          return "Square m"
        else
          return "Square Foot"
        end
      end

      def getPartPrefix()
        return "S-"
      end

      def getTitleName()
        return "Sheet Goods";
      end

      def getHeadingArray()
        headings = ["Part #", "Sub-Assembly", "Description", "Length(L)", "Width(W)", "Thickness(T)", @measureLabel, "Material"]
        return headings
      end

      def getAmountTitleName()
        return "Total Sheet " + @measureLabel
      end

      def getMaterialTitleName()
        return "Sheet Materials"
      end

    end

    ##class DisplaySheet

  end #module CutList
end # module Agav


