module Agav
  module Furnishare
    #########################
    # Display_class superclass      #
    #########################
    class Display_class

      def initialize(inRenderer)
        @renderer = inRenderer
        @metric = true
      end

      def getTitle(title)
        return @renderer.getTitle(title)
      end

      def getHeaderRow(headers)
        return @renderer.getHeaderRow(headers)
      end

      def getFooterRow()
        return @renderer.getFooterRow()
      end

      def getRow(columns)
        return @renderer.getRow(columns)
      end

      def getAmount(amount)
        return @renderer.getAmount(amount)
      end

      def getBlankLine()
        return @renderer.getBlankLine()
      end

      def to_s(inList) end


    end

    ##Display_class

    #########################
    # Display                                              #
    #########################
    class Display < Display_class

      def initialize(inRenderer)
        super(inRenderer)
      end


      def getPartPrefix()
        return "C-"
      end

      def getTitleName()
        return "Components";
      end

      def getHeadingArray()
        headings = ["Part #", "Sub-Assembly", "Description", "Length(L)", "Width(W)", "Thickness(T)", "cub. m", "Material"]
        return headings
      end

      def getAmountTitleName()
        return "Total Component m"
      end

      def getMaterialTitleName()
        return "Component Materials"
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

        end ## end for

        return component
      end

      ## end processRows

      def to_s(inList)

        component = ""
        # component = component + getTitle(getTitleName)
        # component = component + getHeaderRow(getHeadingArray)
        component = component + processRows(inList)
        # component = component + getFooterRow
        component = component + getBlankLine

        return component

      end

      ## end to_s

    end

    ##Display class

    #########################
    # CompactDisplay                                   #
    #########################
    class CompactDisplay < Display

      def getHeadingArray
        %w[Length Width Quantity U D L R Texture Name]
      end

      def processRows(parts)

        component = ""

        lists_by_materials = parts.group_by { |part| part.material + " " + part.getThicknessString }

        lists_by_materials.each { |material_group, material_parts|
          component = component + getTitle(material_group)
          component = component + getHeaderRow(getHeadingArray)

          row = ""
          part_count = 1
          last_part = nil
          columns = Array.new

          material_parts.each { |part|

            if part === last_part
              part_count = part_count + 1
            else
              component = component + row
              part_count = 1
            end

            columns[0] = part.getLengthString
            columns[1] = part.getWidthString
            columns[2] = part_count.to_s
            columns[3] = part.up.output_index.to_s
            columns[4] = part.down.output_index.to_s
            columns[5] = part.left.output_index.to_s
            columns[6] = part.right.output_index.to_s
            columns[7] = part.oriented.to_s
            columns[8] = part.name

            row = getRow(columns)

            last_part = part

          }

          component = component + row

          component = component + getFooterRow
        }
        component

      end
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

      def getPartPrefix()
        return "S-"
      end

      def getHeadingArray()
        headings = ["Part#", "Quantity", "Description", "Length(L)", "Width(W)", "Thickness(T)", "m (per)",
                    "m (total)", "Total Length (m)", "Material"]
        return headings
      end

      def getTitleName()
        return "Sheet Goods";
      end

      def getAmountTitleName()
        return "Total Sheet m"
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

      def getPartPrefix()
        return "S-"
      end

      def getTitleName()
        return "Sheet Goods";
      end

      def getHeadingArray()
        headings = ["Part #", "Sub-Assembly", "Description", "Length(L)", "Width(W)", "Thickness(T)", "m", "Material"]
        return headings
      end

      def getAmountTitleName()
        return "Total Sheet m"
      end

      def getMaterialTitleName()
        return "Sheet Materials"
      end

    end

    ##class DisplaySheet

  end #module CutList
end # module Agav


