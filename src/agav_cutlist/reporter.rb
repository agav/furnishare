require 'agav_cutlist/cutlistutl.rb'
require 'agav_cutlist/layout.rb'
require 'agav_cutlist/boards.rb'
require 'agav_cutlist/parts.rb'
require 'agav_cutlist/drivers.rb'
require 'agav_cutlist/ui.rb'
require 'agav_cutlist/display.rb'
require 'agav_cutlist/renderers.rb'

module Agav
  module Furnishare

    #-----------------------------------------------------------------------------
    # Reporter class
    # This class does the main work of deriving the components from the user selection of the given model,
    # splitting into solid wood components and sheet good components
    # ( and hardware or other 'parts') and then producing the cutlist display in the requested output format
    # All methods are private.
    # There is only 1 'entry point' which is sketchupInit which is called when an action is requested from the gui
    #-----------------------------------------------------------------------------
    class Reporter

      cutlist_Default_Options = {
          :compactList => true,
          :listAllSorted => false,
          :linearFeet => true,
          :outFileUsed => true,
          :outFileName => "CutList.csv",
          :clpFileUsed => true,
          :clpFileName => "CutListPlusImport.csv",
          :printPage => false,
          :showComps => true,
          :showSheet => true,
          :showParts => true,
          :forceBoardFeet => false,
          :layout => false,
          :su5 => false,
          :partWords => ["part"],
          :sheetWords => ["sheet"],
          :svgLayout => false
      }

      @@options = {
          :cutlist_Options => cutlist_Default_Options,
      }

      ##
      # This entry point method is called by the interactive GUI ( html) configurator
      ##
      def sketchupInit(furnishare_options)

        # merge user selected options with the defaults to get the working set for this session
        @@options[:cutlist_Options].merge!(furnishare_options)

        # determine the flavor of the model, metric or inches
        @metric = Furnishare::metricModel?

        # create an input board list - empty for now until we create an interface for it
        @inBoardList = BoardList.new()

        # do the work of the reporter class
        main()
      end

      def main
        if (components() != nil)
          output()
        end
      end

      def getMaterial(component)
        bits = nil
        if component.is_a?(Sketchup::ComponentInstance)
          bits = component.definition.entities
        elsif component.is_a?(Sketchup::Group)
          bits = component.entities
        end ##if

        for f in bits
          if f.is_a? (Sketchup::Face)
            materialClass = f.material
            if (materialClass != nil)
              return materialClass.name
            end
          end
        end
        return "Not assigned"
      end

      ##getMaterial

      #-----------------------------------------------------------------------------
      # The getSubComponent method is called recursively to derive the fundamental component parts of the model from all
      # components and groups in the selection.
      # returns true if a component level has components
      # Adds components to our component data base as it encounters them and sorts them into hardware parts, sheet goods or solid goods
      # If a component has no sub-components below it, then it must be an elemental part and it is added.
      # Top level components are not added if they have sub-components ( this is because the bounding box of the
      # top level components encompasses all of its subcomponents and leads to incorrect cutlists)
      # Top level components have sub-components if it or any of its sub-components have sub-components. In other words
      # sub-componentness is transitive.
      # Basically this is a search for all of the basic components. The only exception is for hardware parts where we
      # return the highest level ( on the assumption that the cutlist is not interested in the sub-components of a hardware part)
      # For example, it's not relevent to know that a castor wheel is made up up a wheel, a metal housing, an axle, nuts, etc, at least not in the cutlist context
      # SubAssemblyName is the name of the parent Component, so that we can record which subassembly a part belongs to
      # When this method is first called, the subAssemblyName is the project, as everthing belongs to the project by default.
      #-----------------------------------------------------------------------------
      def getSubComponents(entityList, level, subAssemblyName)
        puts "checking level=" + level.to_s if Furnishare.verboseComponentDiscovery
        model = Sketchup.active_model
        selection = model.selection
        # the levelHasComponents flag is used to indicate if we have found any parts at this level
        levelHasComponents = false
        for c in entityList
          inSelection = selection.contains? c
          #Sub components do not appear as part of the selection so let them through but only look at visible sub-components
          if ((inSelection || level > 1) && c.layer.visible? && !c.hidden?)

            if ((c.is_a? (Sketchup::ComponentInstance)) || (c.is_a? (Sketchup::Group)))
              # get the name of the component or group or try the inferred name based on its parent if it is a group with no name
              compName = nil
              if c.is_a? (Sketchup::ComponentInstance)
                compName = c.definition.name
                puts "component instance with definition name=" + compName.to_s if Furnishare.verboseComponentDiscovery
              elsif c.is_a? (Sketchup::Group)
                compName = c.name
                puts "group with name=" + compName.to_s if Furnishare.verboseComponentDiscovery
                if (compName == nil || compName == "")
                  compName = Furnishare.group_definition(c).name
                  #let's see if this is a copy of a group which might already have a name
                  if (compName != nil && compName != "")
                    puts "group had no name but is assigned name=" + compName.to_s + " based on its parent" if Furnishare.verboseComponentDiscovery
                  end
                end
              end ##if

              #puts "element: " " type=" + c.typename.to_s + " inSelection=" + inSelection.to_s + " level=" + level.to_s + " visible=" + c.layer.visible?.to_s if CutList.verboseComponentDiscovery

              # get the material name for this part
              partMaterialClass = c.material
              if (partMaterialClass == nil)
                partMaterial = getMaterial(c)
              else
                partMaterial = partMaterialClass.name
              end

              # compare the 'part' words entered by the user to the entity name or to the material name
              # to find the non cutlist parts
              # If this is a hardware part, then we are done with this part

              if (isPartOrSheet(@@options[:cutlist_Options][:partWords], partMaterial) ||
                  isPartOrSheet(@@options[:cutlist_Options][:partWords], compName))
                @partList.add(compName)
                puts "adding part name=" + compName.to_s + " level=" + level.to_s + " as a hardware part since material or name matched" if Furnishare.verboseComponentDiscovery
                puts "+++++++++++++++++++++++++++" if Furnishare.verboseComponentDiscovery
                # since a part was added, mark this level as having components
                levelHasComponents = true
                next #move on to the next part at this level
              end

              # if it is not a hardware part, then for this component or group, go a level deeper to see if it has sub-components
              subList = nil
              if c.is_a? (Sketchup::ComponentInstance)
                subList = c.definition.entities
              elsif c.is_a? (Sketchup::Group)
                subList = c.entities
              end ##if

              # go one level deeper if we found a type of part that might have subparts which we want to add to our list
              # Note: this calls itself recursively until there are no sub-components at the particular level we are looking at
              # compName is the name of the current part which we are exploring to a deeper level ie: the subassembly name
              # Even if this part is ultimtely not added ( because it has sub-conponents) we can record which sub-assembly it belongs to its chold parts
              hasSubComponents = getSubComponents(subList, level + 1, compName)
              if (!hasSubComponents)
                puts "adding part name=" + compName.to_s + ",subAssembly=" + subAssemblyName.to_s + " level=" + level.to_s + " since level=" + (level + 1).to_s + " has no subcomponents" if Furnishare.verboseComponentDiscovery
                puts "+++++++++++++++++++++++++++" if Furnishare.verboseComponentDiscovery
                ### allows names with - + at start etc
                name = " " + compName

                ### If no name is given generate one based on size so that same size unnamed object get grouped together.
                if (name == " ")
                  name = "noname"
                end

                materialClass = c.material
                if (materialClass == nil)
                  material = getMaterial(c)
                else
                  material = materialClass.name
                end

                # compare the 'sheet' words entered by the user against the material name
                # if there is a match then this selected entity becomes a sheet good object
                # Everything else is a solid part
                if (isPartOrSheet(@@options[:cutlist_Options][:sheetWords], material) ||
                    isPartOrSheet(@@options[:cutlist_Options][:sheetWords], name))
                  sheetPart = SheetPart.new(c, name, subAssemblyName, material, @volumeMeasureInMetric)
                  # add to the list
                  @sheetPartList.add(sheetPart)
                else
                  solidPart = SolidPart.new(c,
                                            name, subAssemblyName, material,

                                            @volumeMeasureInMetric)
                  # add to the list
                  @solidPartList.add(solidPart)
                end ##if
              else
                puts "skipping partname=" + compName.to_s + " at level=" + level.to_s + " since level=" + (level + 1).to_s + " has subcomponents" if Furnishare.verboseComponentDiscovery
                puts "--------------------------" if Furnishare.verboseComponentDiscovery
              end
              # if the level below had no subcomponents, then we just added this part at this level, so mark this level as having components
              # if the level below us had subcomponents, then so must this one by transitiveness, even if none specifically
              # existed at this level ( there could be nested top level components), so in either case we set the level to have components
              levelHasComponents = true
              #else
              #puts "skipping entityList element: " " type=" + c.typename.to_s + " inSelection=" + inSelection.to_s + " level=" + level.to_s + " visible=" + c.layer.visible?.to_s if CutList.verboseComponentDiscovery
            end
            #else
            #puts "skipping entityList element: " " type=" + c.typename.to_s + " inSelection=" + inSelection.to_s + " level=" + level.to_s + " visible=" + c.layer.visible?.to_s if CutList.verboseComponentDiscovery
          end #if
        end #for c
        puts "returning levelHasSubcomponents=" + levelHasComponents.to_s + " for level=" + level.to_s if Furnishare.verboseComponentDiscovery
        return levelHasComponents
      end

      #getSubComponents

      #-----------------------------------------------------------------------------
      #  Checks to see if component is a Part or Sheet
      # Make this so it is not case sensitive, so you don't have to enter all possibilities of the same word, capitalized and not
      # Also support special characters similar to Google search to allow specific exclusion of words
      # "-" character ahead of the word means do not include matches on this word ( for example -partition for a part word
      # means that a component named 'partition' should not be considered a part but rather a component which should be
      # included in the cutlist).
      # The '-' must immediately precede the word, no spaces
      #-----------------------------------------------------------------------------
      def isPartOrSheet(inList, compName)
        @found = false
        @exclusionFound = false
        inList.each do |p|
          matchWord = p

          # check for the exclusion syntax ( a negative in front of the word)
          exclude = ((p =~ /^-/) != nil)

          # if  nothing follows the -, then ignore this list word - wrong syntax
          next if ($' == '' && exclude)

          # if the '-' matches the first character, use the part which didn't match as the search string
          matchWord = $' if exclude

          # see if the list word matches anywhere in the component name  - case insensitive
          if ((compName.index(/#{matchWord}/i)) != nil)
            # Exclusions trump inclusions no matter where they are placed in the list
            if (exclude)
              @exclusionFound = true
              @found = false
            end
            @found = true if (!@exclusionFound)
          end
        end # end do loop
        # return the result of the search through all the words.
        return @found
      end

      ## end isPartOrSheet

      #-----------------------------------------------------------------------------
      # Invert the current selection
      # Takes a current model, changes the selection to be the complete inverse of the
      # current selection and returns the modified model
      #-----------------------------------------------------------------------------
      def invert_selection!(model)
        ss = model.selection
        model.entities.each { |e| ss.toggle(e) }
        return model
      end

      #-----------------------------------------------------------------------------
      # Determine the selection from the model ( or force select all if none was selected)
      # and then decompose the selection to a list of components to be included in cutlist,
      # sheet goods and other parts
      # Either pops up an error to the user and returns or if components found,
      # when done, there is a list of components in @solidPartlist, sheet goods in @sheetPartlist
      # and parts in the @partList
      #-----------------------------------------------------------------------------
      def components
        # create a new parts list
        @partList = PartList.new()

        # create the new Solid part list
        @solidPartList = SolidPartList.new()

        # create the new Sheet part list
        @sheetPartList = SheetPartList.new()

        # select the current model
        model = Sketchup.active_model

        # get the parts of the model selected
        selection = model.selection

        # If the current selection is empty, then assume that the entire  model is to be selected.
        # toggle the selection to select all, if still empty, then  display a message
        if (selection.empty?)
          # try selecting all
          # confirm with the user that this is ok
          if (UI.messagebox("Nothing was selected from the model.\nDo you want to select all visible? ", MB_OKCANCEL) == 1)

            # inverse the empty selection to select all
            model = invert_selection!(model)
            @selection_inverted = true

            # get the selection from the model again
            selection = model.selection

            #remove any entities from the selection which are not visible
            selection.each { |entity| selection.toggle(entity) if !entity.layer.visible? }

            # if it's still empty, then there must be nothing in the model.
            if (selection.empty?)
              UI.beep
              UI.messagebox("Your model is empty or no entities are visible.\nNo Cutlist generated.")
              #model.abort_operation
              return nil
            end
          else
            # user cancelled from the select all request
            return nil
          end
        end

        entities = model.entities
        @model_name = model.title

        # check model has a directory path, so we know where to store the output
        model_path = model.path
        puts "Model path=" + model.path.to_s
        if model_path == ""
          UI.beep
          UI.messagebox("You must save the 'Untitled' new model \nbefore making a Component Report !\nNo Cutlist generated.")
          return nil
        end

        # now get the actually directory from the path, so we can put our files in the same directory.

        @model_path = File.dirname(model_path)
        puts "directory= " + @model_path.to_s

        ### show VCB and status info...
        Sketchup::set_status_text(("CutList component discovery..."), SB_PROMPT)
        Sketchup::set_status_text(" ", SB_VCB_LABEL)
        Sketchup::set_status_text(" ", SB_VCB_VALUE)

        #main work of deriving the components from the selection of the model. This updates @solidPartList and @sheetPartList the components and sheet good lists respectively
        puts "Component Discovery start ---->" if Furnishare.verboseComponentDiscovery
        # pass the selection, not the entities
        getSubComponents(selection, 1, @model_name)
        #DEBUG
        puts "Component Discovery end <----" if Furnishare.verboseComponentDiscovery

        # if no components selected or no parts then exit...
        if (@solidPartList.empty? && @sheetPartList.empty? && @partList.empty?)
          UI.beep
          UI.messagebox("No Components found in your model.\nYou must create a Component from your selection.\nClick on Help for more info.\nNo Cutlist will be generated.")
          Sketchup::set_status_text((""), SB_PROMPT)
          return nil
        end

        #finally sort the solid component list and sheet list if the option was selected
        if @@options[:cutlist_Options][:listAllSorted]
          @solidPartList.sort
          @sheetPartList.sort
        end

        Sketchup::set_status_text((""), SB_PROMPT)
        return true
      end

      # components

      def output
        Sketchup::set_status_text(("CutList Output generation..."), SB_PROMPT)
        Sketchup::set_status_text(" ", SB_VCB_LABEL)
        Sketchup::set_status_text(" ", SB_VCB_VALUE)
        ### HTML output ###
        if (@@options[:cutlist_Options][:printPage])
          cutlistHtml = HtmlOutputDriver.new(@@options[:cutlist_Options][:compactList],
                                             @@options[:cutlist_Options][:showComps],
                                             @@options[:cutlist_Options][:showSheet],
                                             @@options[:cutlist_Options][:showParts],
                                             @volumeMeasureInMetric,
                                             @solidPartList,
                                             @sheetPartList,
                                             @partList,
                                             @model_name)
          cutlistHtml.run
        end ## if

        ### File output ###
        if (@@options[:cutlist_Options][:outFileUsed])
          cutlistCsvFile = FileOutputDriver.new(@@options[:cutlist_Options][:compactList],
                                                @@options[:cutlist_Options][:showComps],
                                                @@options[:cutlist_Options][:showSheet],
                                                @@options[:cutlist_Options][:showParts],
                                                @volumeMeasureInMetric,
                                                @solidPartList,
                                                @sheetPartList,
                                                @partList,
                                                @model_name,
                                                @model_path,
                                                @@options[:cutlist_Options][:outFileName])
          cutlistCsvFile.run
        end ## if

        ### CutListPlus output ###
        if (@@options[:cutlist_Options][:clpFileUsed])
          cutlistClpFile = ClpFileOutputDriver.new(@@options[:cutlist_Options][:compactList],
                                                   @@options[:cutlist_Options][:showComps],
                                                   @@options[:cutlist_Options][:showSheet],
                                                   @@options[:cutlist_Options][:showParts],
                                                   @volumeMeasureInMetric,
                                                   @solidPartList,
                                                   @sheetPartList,
                                                   @partList,
                                                   @model_name,
                                                   @model_path,
                                                   @@options[:cutlist_Options][:clpFileName])
          cutlistClpFile.run
        end ## if

        if (@@options[:cutlist_Options][:layout])
          @unplacedPartsList = nil if !@@options[:layout_Options][:displayUnplacedParts]
          cutlistLayoutHtml = HtmlLayoutDriver.new(@layoutBoards,
                                                   @layoutSheets,
                                                   @unplacedPartsList,
                                                   @model_name)
          cutlistLayoutHtml.run
        end

        if (@@options[:cutlist_Options][:svgLayout])
          @unplacedPartsList = nil if !@@options[:layout_Options][:displayUnplacedParts]
          cutlistSvgLayoutHtml = SvgLayoutDriver.new(@layoutBoards,
                                                     @layoutSheets,
                                                     @unplacedPartsList,
                                                     @model_name,
                                                     @model_path)
          cutlistSvgLayoutHtml.run
        end
        Sketchup::set_status_text((""), SB_PROMPT)
      end

      #def output

    end

    #class Reporter

  end # module CutList
end # module Agav
