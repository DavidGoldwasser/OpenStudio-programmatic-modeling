# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class GetExteriorWallConstructionFromBCL < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return " Get Exterior Wall Construction From BCL"
  end

  # human readable description
  def description
    return "This will look at the type of exterior walls used on yoru model, and will populate a choice list with those types of walls from the Building Component Library. The selected Construction will replace all exterior walls in your model."
  end

  # human readable description of modeling approach
  def modeler_description
    return "If your model contains more than one type of exterior walls then both will be included in the search. Also try to search attributes for climate zone, but may have to map naming to match between our templates and what is on BCL for climate zones. "
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # Check Auth Key in LocalBCL instance (while it works without authentication we don't want people doing this)
    library = OpenStudio::LocalBCL::instance()
    if (library::prodAuthKey().empty?)
      good_key = false
    else
      good_key = true
    end

    # get array of construction types used on exterior walls
    construction_type_array = ["Mass"] # temporary pre-populated array for when loop below is commented out

    # custom array for attribute search.
    construction_type_array = []
    model.getConstructions.each do |construction|

      # todo slow, so commented out for now
      next if construction.getNetArea == 0.0

      # get construction and standard
      constructionStandard = construction.standardsInformation

      # get intended surface and standards construction type
      intendedSurfaceType = constructionStandard.intendedSurfaceType.to_s
      constructionType = constructionStandard.standardsConstructionType.to_s

      if intendedSurfaceType == "ExteriorWall"
        construction_type_array << constructionType
      end

    end

    # get climate zone so can filter on that if provided
    ashraeClimateZone = nil
    climateZones = model.getClimateZones
    climateZones.climateZones.each do |climateZone|
      if climateZone.institution == "ASHRAE"
        ashraeClimateZone = climateZone.value
      end
    end

    # Search for components
    remote = OpenStudio::RemoteBCL.new
    page_counter = 0
    page_fails_test = false
    last_page_found = false
    all_results = []
    max_results = 40 # customize this to limit size of choice list
    construction_attribute = "Exterior Wall"
    climate_zone_prefix = "ASHRAE 2004:"
    until last_page_found or all_results.size >= max_results or page_fails_test

      # (search string, component type, result page to return)
      responses = remote.searchComponentLibrary("#{construction_attribute} #{ashraeClimateZone}", "Construction Assembly",page_counter)
      # note: adding to string of main search speed things up a lot, but still need to search attributes

      if responses.size == 0
        last_page_found = true
      else

        # starting results size
        starting_counter = all_results.size # added this so it doesn't go through thousands of results
        responses.each do |response|

          # extra check to stop if we hit max results
          next if all_results.size >= max_results

          # search specifically on State attribute
          construction_test = false
          climate_zone_test = false
          construction_type_test = false

          response.attributes.each do |attribute|
            if (attribute.name.to_s == "Construction") and (attribute.valueAsString == construction_attribute)
              construction_test = true
            end

            if ashraeClimateZone == ""
              climate_zone_test = true # if no climate zone set then don't filter by it
            else
              if (attribute.name.to_s == "Climate Zone") and (attribute.valueAsString == "#{climate_zone_prefix}#{ashraeClimateZone}")
                climate_zone_test = true
              end
            end

            # loop through all exterior wall construction types in the model
            if construction_type_array.size == 0
              construction_type_test = true # if there are no exterior walls than accept any types of exterior walls for the search
            else
              construction_type_array.uniq.each do |construction_type|
                if (attribute.name.to_s == "Construction Type") and (attribute.valueAsString == construction_type)
                  construction_type_test = true
                end
              end
            end

          end

          # add to results if passes all tests
          if construction_test and climate_zone_test and construction_type_test
            all_results << response
          end

        end

        # set flag if no results were found on this page to force it to stop
        if all_results.size == starting_counter
          page_fails_test = true
        end

      end

      # update page count
      page_counter += 1

    end

    # Create options for user prompt
    choices_display = OpenStudio::StringVector.new
    choices_uid = OpenStudio::StringVector.new
    bcl_args_hash = {}
    all_results.each do |response|
      bcl_args_hash[response.name.to_s] = response.uid.to_s
    end

    #looping through sorted hash of constructions
    bcl_args_hash.sort.map do |key,value|
      choices_display << key
      choices_uid << value
    end

    if not good_key
      puts "BCL authentication failed"

      # don't show results if they are not logged in
      choices_display = []
      choices_uid = []

      choices_display << "*BCL authentication failed*"
      choices_uid << ""
    elsif all_results.empty?
      puts "No BCL results found"

      choices_display << "*No BCL results found*"
      choices_uid << ""
    elsif all_results.size >= max_results
      puts "List limited to #{max_results} results"

      choices_display << "*List limited to #{max_results} results*"
      choices_uid << ""
    end

    #make an argument bcl component
    construction = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("construction", choices_uid, choices_display,true)
    construction.setDisplayName("Pick An Exterior Wall Construction from BCL.")
    args << construction

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    construction = runner.getStringArgumentValue("construction",user_arguments)

    if not construction
      runner.registerError("No construction file was selected.")
      return false
    end

    uid = construction
    runner.registerInfo("uid is #{uid}")

    if uid.empty?
      runner.registerError("Error, could not find uid for #{construction.valueAsString}.  Please try a different construction file.")
      return false
    end

    remote = OpenStudio::RemoteBCL.new
    remote.downloadComponent(uid)
    component = remote.waitForComponentDownload()

    if component.empty?
      runner.registerError("Cannot find local component")
      return false
    end
    component = component.get

    # get epw file
    files = component.files("osc")
    if files.empty?
      runner.registerError("No file found")
      return false
    end
    construction_path = component.files("osc")[0]
    construction_file = OpenStudio::IdfFile::load(construction_path)
    vt = OpenStudio::OSVersion::VersionTranslator.new
    constructionComponent = vt.loadComponent(OpenStudio::Path.new(construction_path))

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getConstructions.size} constructions.")

    if constructionComponent.empty?
      runner.registerError("translateSurfaceConstruction: Cannot load construction component '#{construction_file}'")
      return false
    else
      object = constructionComponent.get.primaryObject
      if object.to_Construction.empty?
        runner.registerError("translateSurfaceConstruction: Construction component '#{construction_file}' does not include a construction object")
        return false
      else
        componentData = model.insertComponent(constructionComponent.get)
        if componentData.empty?
          runner.registerError("translateSurfaceConstruction: Failed to insert construction component '#{construction_file}' into model")
          return false
        else
          new_construction = componentData.get.primaryComponentObject.to_Construction.get
        end
      end
    end

    # loop through construction sets
    counter = 0
    model.getDefaultConstructionSets.each do |construction_set|
      next if not construction_set.defaultExteriorSurfaceConstructions.is_initialized
      surface_construction_set = construction_set.defaultExteriorSurfaceConstructions.get
      next if not surface_construction_set.wallConstruction.is_initialized # don't change it if not set yet
      surface_construction_set.setWallConstruction(new_construction)
      counter += 1
    end
    runner.registerInfo("Altered exterior wall construction on #{counter} construction sets.")

    # loop through hard assigned constructions
    counter = 0
    model.getSurfaces.each do |surface|
      next if not (surface.surfaceType.to_s == "Wall" and surface.outsideBoundaryCondition.to_s == "Outdoors" and surface.construction.is_initialized)
      next if surface.isConstructionDefaulted # only change if hard assigned
      surface.setConstruction(new_construction)
      counter += 1
    end
    runner.registerInfo("Altered #{counter} exterior wall surfaces with hard assigned constructions.")

    # register final condition
    runner.registerFinalCondition("The model finished with #{model.getConstructions.size} constructions")

    return true

  end
  
end

# register the measure to be used by the application
GetExteriorWallConstructionFromBCL.new.registerWithApplication
