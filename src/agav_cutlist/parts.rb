module Agav
  module Furnishare
    #-----------------------------------------------------------------------------
    # Class PartList - holds all selected components which are neither a
    # solid part nor a sheet part - typically this would be hardware...or things like bryce
    #  if you include him in your model
    # Only the minimal amount of data is kept for parts at this time.
    # The following is the structure for a hardware parts list
    #  parts - array of all unique hardware part names ( only the name is stored)
    #  partCount - array of counts of each unique hardware part
    #
    # Note: since only this data is kept only these two fields can be included in any
    # output. If any other attribute is required, then a Part class should be created
    # and the PartList would become an array of Part objects  much as we do with
    # SolidPartList and SheetPartList
    # The part class could contain other attributes desired ( eg, dimensions, material etc)
    # but probably would not need to be as complex as SolidPart and SheetPart since
    # normally we just display a list of these.
    # For example you might want to know that a knob is made of brass or oak.
    # For now, this could be embedded into your part name.
    #----------------------------------------------------------------------------------
    class PartList

      ### Constructor
      def initialize()
        @parts = Array.new
        @partCount = Array.new
      end

      ### Constructor

      def parts
        @parts
      end

      ###def parts

      def partCount
        @partCount
      end

      ###def partCount

      ### Adds a part to the list.
      # search the part array for a part existing with same name
      # if it exists, increment the number of those type of parts
      # otherwise, add a new part to the part array and initialize the count of these parts to 1
      def add(inPart)
        index = @parts.index(inPart)
        if (index != nil)
          @partCount[index] = @partCount[index] + 1
        else
          @parts.push(inPart)
          @partCount.push(1)
        end ###if
      end

      ###def add

      def empty?
        @parts.length == 0
      end

      def getList
        @parts
      end

    end


    ###Class Edge
    class Edge
      attr_accessor :material, :thickness, :output_index

      def initialize(material = nil, thickness = 0, output_index = 0)
        @material = material
        @thickness = thickness
        @output_index = output_index
      end

    end

    ###Class PartList

    #-----------------------------------------------------------------------------
    # cutlist  base class - represent all cutlist parts of the model, be they solid or sheet
    # All lengths are stored in sketchup's default inches unless the name says otherwise
    #-----------------------------------------------------------------------------
    class CutListPart
      def initialize(c, name, subAssemblyName, material, edge_material_options)
        # always get the bounding box from the definition if it exists
        # components have definition attributes (same for all components) which is accessible through the component entity
        # groups also have definitions but it is not stored against the group, but you can search through the definitions list to
        # find which instance belongs to which group
        boundingBox = c.bounds
        if c.respond_to? "definition"
          boundingBox = c.definition.bounds
        else
          if c.is_a?(Sketchup::Group)
            group_definition = Furnishare::group_definition(c)
            boundingBox = group_definition.bounds
          end
        end

        trans = c.transformation.to_a
        scalex = Math.sqrt(trans[0] ** 2 + trans[1] ** 2 + trans[2] ** 2)
        scaley = Math.sqrt(trans[4] ** 2 + trans[5] ** 2 + trans[6] ** 2)
        scalez = Math.sqrt(trans[8] ** 2 + trans[9] ** 2 + trans[10] ** 2)

        size_x = boundingBox.width.to_mm * scalex
        size_y = boundingBox.height.to_mm * scaley
        size_z = boundingBox.depth.to_mm * scalez

        left_bound = Geom::BoundingBox.new
        right_bound = Geom::BoundingBox.new
        up_bound = Geom::BoundingBox.new
        down_bound = Geom::BoundingBox.new
        front = Geom::BoundingBox.new
        back = Geom::BoundingBox.new

        #				       F,U,R	  U,R,F
        #        			   ↓      ↙
        # 			      6-------7
        # 			     /|      /|
        # 			    / |     / |
        # L,B,D →  4-------5  |	← R,F,U
        # 			   |  2----|--3
        # 			   | /     | /
        # 			   0-------1
        #      		↗		  ↑
        # 	   D,L,B	B,D,L


        if size_z < size_y and size_z < size_x
          @thickness = size_z
          @length = size_x
          @width = size_y
          left_bound.add(boundingBox.corner(0), boundingBox.corner(2), boundingBox.corner(4), boundingBox.corner(6))
          right_bound.add(boundingBox.corner(1), boundingBox.corner(3), boundingBox.corner(5), boundingBox.corner(7))
          up_bound.add(boundingBox.corner(2), boundingBox.corner(3), boundingBox.corner(6), boundingBox.corner(7))
          down_bound.add(boundingBox.corner(0), boundingBox.corner(1), boundingBox.corner(4), boundingBox.corner(5))
          front.add(boundingBox.corner(4), boundingBox.corner(5), boundingBox.corner(6), boundingBox.corner(7))
          back.add(boundingBox.corner(1), boundingBox.corner(1), boundingBox.corner(2), boundingBox.corner(3))
        elsif size_y < size_z and size_y < size_x
          @thickness = size_y
          @length = size_z
          @width = size_x
          left_bound.add(boundingBox.corner(1), boundingBox.corner(1), boundingBox.corner(2), boundingBox.corner(3))
          right_bound.add(boundingBox.corner(4), boundingBox.corner(5), boundingBox.corner(6), boundingBox.corner(7))
          up_bound.add(boundingBox.corner(1), boundingBox.corner(3), boundingBox.corner(5), boundingBox.corner(7))
          down_bound.add(boundingBox.corner(0), boundingBox.corner(2), boundingBox.corner(4), boundingBox.corner(6))
          front.add(boundingBox.corner(2), boundingBox.corner(3), boundingBox.corner(6), boundingBox.corner(7))
          back.add(boundingBox.corner(0), boundingBox.corner(1), boundingBox.corner(4), boundingBox.corner(5))
        else
          @thickness = size_x
          @length = size_y
          @width = size_z
          left_bound.add(boundingBox.corner(0), boundingBox.corner(1), boundingBox.corner(4), boundingBox.corner(5))
          right_bound.add(boundingBox.corner(2), boundingBox.corner(3), boundingBox.corner(6), boundingBox.corner(7))
          up_bound.add(boundingBox.corner(4), boundingBox.corner(5), boundingBox.corner(6), boundingBox.corner(7))
          down_bound.add(boundingBox.corner(1), boundingBox.corner(1), boundingBox.corner(2), boundingBox.corner(3))
          front.add(boundingBox.corner(1), boundingBox.corner(3), boundingBox.corner(5), boundingBox.corner(7))
          back.add(boundingBox.corner(0), boundingBox.corner(2), boundingBox.corner(4), boundingBox.corner(6))
        end


        dimCalculations()
        @material = material
        @name = strip(name, @length.to_s, @width.to_s, @thickness.to_s)
        @subAssemblyName = strip(subAssemblyName, @length.to_s, @width.to_s, @thickness.to_s)
        @canRotate = true
        @metricVolume = true
        @metric = Furnishare.metricModel?
        @locationOnBoard = nil

        @left = Edge.new()
        @right = Edge.new()
        @up = Edge.new()
        @down = Edge.new()

        c.entities.each do |entity|
          if (entity.is_a? Sketchup::Face) && (entity.material != nil)
            face_center = entity.bounds.center
            if left_bound.contains?(face_center)
              @left.material = entity.material.name
            elsif right_bound.contains?(face_center)
              @right.material = entity.material.name
            elsif up_bound.contains?(face_center)
              @up.material = entity.material.name
            elsif down_bound.contains?(face_center)
              @down.material = entity.material.name
            end
          end
        end

        [@left, @right, @up, @down].each do |edge|
          if edge.material == nil
            next
          end
          edgeMaterialOption = edgeMaterial(edge_material_options, edge.material)
          if edgeMaterialOption != nil
            edge.thickness = edgeMaterialOption["thickness"].to_f.mm
            edge.output_index = edgeMaterialOption["index"].to_i
          end
        end

        @cutting_length = (@length.mm - @left.thickness - @right.thickness).to_mm
        @cutting_width = (@width.mm - @up.thickness - @down.thickness).to_mm


      end

      def edgeMaterial(edge_material_options, material)
        edge_material_options.each do |edge_material_option|
          if Furnishare.wordMatchesTokens(edge_material_option["words"].split(" "), material)
            return edge_material_option
          end
        end
        nil
      end

      def dimCalculations
        @area = @length * @width

        # part in pixels scale  12in=100px
        # Useful for display purpose but not accurate enough for part comparisons
        @length_px = Furnishare::float_round_to(0, ((@length / 12) * 100).to_f)
        @width_px = Furnishare::float_round_to(0, ((@width / 12) * 100).to_f)
      end

      def getLeft
        @left
      end

      def getRight
        @right
      end

      def getUp
        @up
      end

      def getDown
        @down
      end

      # Bubble sort
      # sorts in ascending order
      def getSortedArray(array)
        size = array.size()
        pass = size
        for i in (0..pass - 2)
          for j in (0..pass - 2)
            if (array[j + 1] < array[j])
              tmp = array[j]
              array[j] = array[j + 1]
              array[j + 1] = tmp
            end
          end
        end
        return array
      end

      # used to make the name unique if no name was
      # given to it. The new name is based on the "noname_" + the
      #concatenation of the dimensions of the part. This allows us
      # to identify identical parts even if they have no name.
      # The order of the dimensions is arbitrary as long as
      # it is consistent but typically same order as the output
      # ie: length, width, thickness
      def strip(name, inV1, inV2, inV3)
        val = name
        if (name == "noname")
          val = ("noname_" + inV1 + inV2 + inV3)
          val = val.gsub(/[ ]/, "_")
          val = val.gsub(/['~"]/, "")
          val = val.gsub(/[\/]/, "-")
        end ## end if
        return val
      end

      def getLengthString
        Furnishare.length_to_mm(@cutting_length)
      end

      def getWidthString
        Furnishare.length_to_mm(@cutting_width)
      end

      def getWidth
        @width
      end

      def getLength
        @length
      end

      def getThicknessString
        @thickness.mm.to_s.delete(' mm')
      end

      def getThickness
        @thickness
      end

      #aka c[5]
      def getMaterial
        @material
      end

      #aka c[0]
      def getName
        @name
      end

      def getSubAssemblyName
        @subAssemblyName
      end

      #aka c[4] for solid parts
      def getBoardFeet
        #1 mm = 0.0393700787 inches
        # 1 in = 25.40000002590800002642610026955 mm
        # 1bd ft = 144 cu in
        # 1bd ft = 2359.7372232207958956904236222001 cu cm
        # divide by 1000000 to get cu.m.
        #(@boardFeet*2359.7424).round_to(6)
        #(@width.to_l*@length.to_l*@thickness.to_l*2359.7383).round_to(6)
        Furnishare::float_round_to(6, (1 * (2359.7372232207958956904236222001 / 1000000)))
      end

      def getBoardFeetLabel
        return "Cubic m"
      end

      # aka c[4] for sheet parts
      def getSquareFeet
        Furnishare::float_round_to(6, (1 * (0.092903040189522201889968968842358)))
      end

      def getCanRotate
        @canRotate
      end

      def getLengthPx
        @length_px
      end

      def getWidthPx
        @width_px
      end

      def addLocationOnBoard(coords)
        # top left coordinate of the location of the part on the board
        # stored in standard dimension units ( ie: everything is relative to the actual size of the board)
        @locationOnBoard = coords
      end

      def getLocationOnBoard
        # return standard dimennsion units ( ie: everything is relative to the actual size of the board)
        @locationOnBoard
      end

      def getLocationOnBoardInPx
        # return top left coordinate (x,y) of the part's location on the board for drawing purposes
        # convert the standard dimension units expressed to Px ( 100px/inch)
        Array[Furnishare::float_round_to(0, ((@locationOnBoard[0] / 12) * 100).to_f), Furnishare::float_round_to(0, ((@locationOnBoard[1] / 12) * 100).to_f)]
      end

      def changeWidth(width)
        @width = width.inch
        dimCalculations()
      end

      def changeThickness(thickness)
        @thickness = thickness.inch
        dimCalculations()
      end

      def convertMeasureForCLP(measure)
        # CutList Plus has some import limitations. Inches, feet, mm and cm are
        # accepted but not meters. So here we convert the measure back to a float in inches
        # if the model is in meters. This is just for CutListPlus import file generation
        if Furnishare::modelInMeters?
          measure = Furnishare::float_round_to(4, measure.to_f)
        end
        return measure
      end

      def deep_clone
        Marshal::load(Marshal.dump(self))
      end

      def summary
        return (getName + " (" + getLengthString + ", " + getWidthString + ", " + getThicknessString + ") " + getMaterial)
      end
    end

    #-----------------------------------------------------------------------------
    # Class SolidPart - to represent all solid parts which are part of the cut list and layout
    # Derived from base class CutListPart
    #-----------------------------------------------------------------------------
    class SolidPart < CutListPart

      # initialization for class SolidPart
      # c - sketchup entity, either component or group
      # name - is a string of the name of the entity
      # material - is a string of the material for this entity
      # nominalMargin is a number in 16ths of the allowance required in the thickness over the final part size
      # quarter is an array of 4 elements, being boolean values of fourq, fiveq, sixq and eightq respectively as entered by the user
      def initialize(c, name, subAssemblyName, material, edge_materials)
        super(c, name, subAssemblyName, material, edge_materials)
      end

      def dimCalculations
        super
      end

      ## Turn a thickness into a nominal thickness ##
      def handleNominalSize(inThickness)
        result = inThickness
        return result
      end

      ## handleNominalSize

      def getThicknessString
        @thickness.mm.to_s.delete(' mm')
      end

      def getMarginThickness
        0
      end

      def getThickness
        @thickness
      end

    end

    #-----------------------------------------------------------------------------
    # Class SheetPart - to represent all components cut from sheet stock
    # and which are part of the cut list and layout. Derived from base class CutListPart
    #-----------------------------------------------------------------------------
    class SheetPart < CutListPart

      # for sheet goods, the board ft measure is actually the square footage
      def getBoardFeet
        getSquareFeet
      end

      def getBoardFeetLabel
        return "Square m"
      end

    end

    #-----------------------------------------------------------------------------
    # Base class for all lists of components
    # Maintains a list of all parts which can be sorted by name within length within board feet
    # simultaneously maintains a list of parts indexed by [material,thickness]
    #-----------------------------------------------------------------------------
    class CutListPartList
      # Constructor
      def initialize()
        # array of cut list part objects
        @componentList = Array.new
        @componentListByMaterialAndThickness = Hash.new
      end

      def addToPartDatabase(cutListPart)
        return if cutListPart == nil
        material = cutListPart.getMaterial
        # get thickness and convert to string to use as an index in the hash
        thickness = cutListPart.getThickness.inch.to_s
        #puts " thickness=" +  thickness.to_s
        if !@componentListByMaterialAndThickness.include? material
          # this a new material, create a new entry in the material array
          newThicknessHash = Hash.new
          #puts "new material hash for " + material.to_s
          @componentListByMaterialAndThickness[material] = newThicknessHash
        end
        # If this is a new thickness, create a new parts array and a new hash to this array
        # using this new thickness
        if !@componentListByMaterialAndThickness[material].include? thickness
          #create a new array for the parts at this thickness
          #puts "new thickness hash for " + thickness.to_s + " " + material.to_s
          newPartArray = Array.new
          @componentListByMaterialAndThickness[material][thickness] = newPartArray
        end
        # in any case, add this part
        @componentListByMaterialAndThickness[material][thickness].push(cutListPart)
      end

      def removeFromPartDatabase(cutListPart)
        return if cutListPart == nil
        # when removing we must first update the hash list of [material,thickness]
        material = cutListPart.getMaterial
        # get thickness and convert to string to use as an index in the hash
        thickness = cutListPart.getThickness.inch.to_s
        #puts "removing part from material=" + material + " thickness= " + thickness
        #puts @componentListByMaterialAndThickness[material].to_s
        #puts @componentListByMaterialAndThickness[material][thickness].to_s
        @componentListByMaterialAndThickness[material][thickness].delete(cutListPart)
        #remove the thickness hash if now empty
        if @componentListByMaterialAndThickness[material][thickness].empty?
          #remove the thickness hash
          @componentListByMaterialAndThickness[material].delete(thickness)
        end
        #remove the material hash if now empty
        if @componentListByMaterialAndThickness[material].empty?
          #remove the material hash
          @componentListByMaterialAndThickness.delete(material)
        end
      end

      # add a cut list object to the array
      def add(cutListPart)
        @componentList.push(cutListPart)
        addToPartDatabase(cutListPart)
      end

      def remove(cutListPart)
        removeFromPartDatabase(cutListPart)
        @componentList.delete(cutListPart)
      end

      def empty?
        @componentList.length == 0
      end

      def count
        @componentList.length
      end

      def allPartsSameMaterial?
        return true if @componentList.empty?
        material = @componentList.first.getMaterial
        return (@componentList.select { |x| x.getMaterial != material } == nil)
      end

      def allPartsSameThickness?
        return true if @componentList.empty?
        thickness = @componentList.first.getThickness
        return (@componentList.select { |x| x.getThickness != thickness } == nil)
      end

      # returns the list in its current context
      def getList
        return @componentList
      end

      def removeFirst!
        #removes the first part in the list (biggest part in a sorted list) and return it.
        # returns nil if the list is empty
        cutListPart = @componentList.shift
        removeFromPartDatabase(cutListPart)
        return cutListPart
      end

      def insertFirst!(cutListPart)
        #add a part back to the front of the list
        @componentList.unshift(cutListPart)
        addToPartDatabase(cutListPart)
      end

      # sort and return a copy of the list. Does not change the component list
      def sort
        sortByName
      end

      # sort by name and return a copy of the list. Does not change the component list
      # This sorted view is used so that the compact view lists by component name
      def sortByName
        # sort in descending order by name with no regard to board feet or part length
        # return the sorted list
        sortedComponentList = @componentList
        size = sortedComponentList.size()
        pass = size
        for i in (0..pass - 2)
          for j in (0..pass - 2)
            if (sortedComponentList[j].getName > sortedComponentList[j + 1].getName)
              tmp = sortedComponentList[j + 1]
              sortedComponentList[j + 1] = sortedComponentList[j]
              sortedComponentList[j] = tmp
            end
          end
        end
        sortedComponentList
      end

      # sort and overwrite the list with the sorted list
      def sort!
        sortedList = @componentList.sort
        @componentList = sortedList
      end

      def deep_clone
        Marshal::load(Marshal.dump(self))
      end

      def splitPartsListByMaterial
        @listOfPartsListsByMaterial = Array.new
        # the default is a single entry in the array with the original partsList if all parts have the same material
        if allPartsSameMaterial?
          @listOfPartsListsByMaterial.push(self)
          return @listOfPartsListsByMaterial
        end
        # some parts are of a different material. Retrieve those. Each new material gets its own partsList
        # all thicknesses are lumped together
        @componentListByMaterialAndThickness.each { |material, thickness|
          partListByMaterial = CutListPartList.new
          @componentListByMaterialAndThickness[material].each { |thickness, part|
            @componentListByMaterialAndThickness[material][thickness].each { |part|
              partListByMaterial.add(part)
            }
          }
          @listOfPartsListsByMaterial.push(partListByMaterial)
        }
        return @listOfPartsListsByMaterial
      end

      def splitPartsListByThicknessAndMaterial
        @listOfPartsListsByMaterialAndThickness = Array.new
        # the default is a single entry in the array with the original partsList if all parts have the same material and thickness
        if allPartsSameMaterial? && allPartsSameThickness?
          @listOfPartsListsByMaterialAndThickness.push(self)
          return @listOfPartsListsByMaterialAndThickness
        end
        # else some parts are of a different material. Retrieve those. Each new combination of material,thickness
        # gets its own list
        @componentListByMaterialAndThickness.each { |material, thickness|
          @componentListByMaterialAndThickness[material].each { |thickness, part|
            partListByThicknessAndMaterial = CutListPartList.new
            @componentListByMaterialAndThickness[material][thickness].each { |part|
              partListByThicknessAndMaterial.add(part)
            }
            @listOfPartsListsByMaterialAndThickness.push(partListByThicknessAndMaterial)
          }
        }
        #puts @listOfPartsListsByMaterialAndThickness.to_s
        return @listOfPartsListsByMaterialAndThickness
      end

      def splitPartsListByThickness
        @listOfPartsListsByThickness = Array.new
        if allPartsSameThickness?
          @listOfPartsListsByThickness.push(self)
          return @listOfPartsListsByThickness
        end
        # else some parts are of a different thickness. Retrieve those. Each new thickness regardless of material gets its own list
        # search the database and create a hash by thickness, which is easier to populate, then convert to an array at the end.
        thicknessHash = Hash.new
        @componentListByMaterialAndThickness.each { |material, thickness|
          @componentListByMaterialAndThickness[material].each { |thickness, part|
            if !thicknessHash.include? thickness
              puts "List Parts by Thickness: new thickness=" + thickness
              partListByThickness = CutListPartList.new
              thicknessHash[thickness] = partListByThickness
            end
            @componentListByMaterialAndThickness[material][thickness].each { |part|
              thicknessHash[thickness].add(part)
            }
          }
        }
        #convert hash to our array
        thicknessHash.each { |thickness, partList| @listOfPartsListsByThickness.push(partList) }
        return @listOfPartsListsByThickness
      end

      def +(cutListPartList)
        # add the parts on the list and return self.
        return if cutListPartList == nil
        cutListPartList.getList.each { |part| add(part) }
      end


    end

    #-----------------------------------------------------------------------------
    # Class SolidPartList - List of all solid component parts which are part
    # of the cut list and layout
    #-----------------------------------------------------------------------------
    class SolidPartList < CutListPartList
    end

    #-----------------------------------------------------------------------------
    # Class SheetPartList - List of all sheet component parts which are part
    # of the cut list and layout
    #-----------------------------------------------------------------------------
    class SheetPartList < CutListPartList
    end

    #-----------------------------------------------------------------------------
    # Class BoardList - List of all boards available for the layout where
    # boards have been specified by the user. A list of raw boards.
    #-----------------------------------------------------------------------------
    class BoardList < CutListPartList
    end

  end

  # module CutLlist
end # module Agav
