require 'agav_cutlist/utils.rb'
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

      ##
      # This entry point method is called by the interactive GUI ( html) configurator
      ##
      def sketchupInit(furnishare_options)

        @options = furnishare_options
        @metric = Furnishare::metricModel?

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
          if ((inSelection || level > 1) && c.layer.visible? && !c.hidden?)
            if ((c.is_a? (Sketchup::ComponentInstance)) || (c.is_a? (Sketchup::Group)))
              compName = nil
              if c.is_a? (Sketchup::ComponentInstance)
                compName = c.definition.name
              elsif c.is_a? (Sketchup::Group)
                compName = c.name
                if (compName == nil || compName == "")
                  compName = Furnishare.group_definition(c).name
                  if (compName != nil && compName != "")
                    puts "group had no name but is assigned name=" + compName.to_s + " based on its parent" if Furnishare.verboseComponentDiscovery
                  end
                end
              end
              partMaterialClass = c.material

              if partMaterialClass == nil
                partMaterial = getMaterial(c)
              else
                partMaterial = partMaterialClass.name
              end

              part_words = @options["partWords"].split(" ")
              if Furnishare.wordMatchesTokens(part_words, partMaterial) || Furnishare.wordMatchesTokens(part_words, compName)
                @partList.add(compName)
                levelHasComponents = true
                next
              end

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
                name = " " + compName

                if (name == " ")
                  name = "noname"
                end

                materialClass = c.material
                if (materialClass == nil)
                  material = getMaterial(c)
                else
                  material = materialClass.name
                end

                sheet_words = @options["sheetWords"].split(" ")
                if Furnishare.wordMatchesTokens(sheet_words, material) || Furnishare.wordMatchesTokens(sheet_words, name)
                  sheetPart = SheetPart.new(c, name, subAssemblyName, @options["edges"])
                  @sheetPartList.add(sheetPart)
                else
                  solidPart = SolidPart.new(c, name, subAssemblyName, @options["edges"])
                  @solidPartList.add(solidPart)
                end
              end
              levelHasComponents = true
            end
          end
        end
        return levelHasComponents
      end

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

        if (selection.empty?)
          if (UI.messagebox("Nothing was selected from the model.\nDo you want to select all visible? ", MB_OKCANCEL) == 1)
            model = invert_selection!(model)
            @selection_inverted = true
            selection = model.selection
            selection.each { |entity| selection.toggle(entity) if !entity.layer.visible? }
            if (selection.empty?)
              UI.beep
              UI.messagebox("Your model is empty or no entities are visible.\nNo Cutlist generated.")
              return nil
            end
          else
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

        @model_path = File.dirname(model_path)

        ### show VCB and status info...
        Sketchup::set_status_text(("CutList component discovery..."), SB_PROMPT)
        Sketchup::set_status_text(" ", SB_VCB_LABEL)
        Sketchup::set_status_text(" ", SB_VCB_VALUE)

        getSubComponents(selection, 1, @model_name)

        if (@solidPartList.empty? && @sheetPartList.empty? && @partList.empty?)
          UI.beep
          UI.messagebox("No Components found in your model.\nYou must create a Component from your selection.\nClick on Help for more info.\nNo Cutlist will be generated.")
          Sketchup::set_status_text((""), SB_PROMPT)
          return nil
        end

        @solidPartList.sort
        @sheetPartList.sort

        Sketchup::set_status_text((""), SB_PROMPT)

        true
      end

      def output
        Sketchup::set_status_text(("CutList Output generation..."), SB_PROMPT)
        Sketchup::set_status_text(" ", SB_VCB_LABEL)
        Sketchup::set_status_text(" ", SB_VCB_VALUE)
        ### HTML output ###

        driver = HtmlOutputDriver.new(@solidPartList, @sheetPartList, @partList, @model_name)
        driver.run

        Sketchup::set_status_text((""), SB_PROMPT)
      end
    end
  end
end
