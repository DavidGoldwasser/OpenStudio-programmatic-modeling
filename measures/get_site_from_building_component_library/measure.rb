# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class GetSiteFromBuildingComponentLibrary < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return " Get Site from Building Component Library"
  end

  # human readable description
  def description
    return "Populate choice list from BCL, then selected site will be brought into model. This will include the weather file, design days, and water main temperatures."
  end

  # human readable description of modeling approach
  def modeler_description
    return "To start with measure will hard code a string to narrow the search. Then a shorter list than all weather files on BCL will be shown. In the future woudl be nice to select region based on climate zone set in building object."
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

    # hard coded city for BCL search
    state = "CO" # using CO instead of Denver to test out multi-page results

    # Search for weather files
    remote = OpenStudio::RemoteBCL.new
    page_counter = 0
    page_fails_test = false
    last_page_found = false
    all_results = []
    max_results = 40 # customize this to limit size of choice list
    until last_page_found or all_results.size >= max_results or page_fails_test

      # (search string, component type, result page to return)
      responses = remote.searchComponentLibrary(state, "Site",page_counter)
      # note: adding to string of main search speed things up a lot, but still need to search attributes

      if responses.size == 0
        last_page_found == true
      else

        # starting results size
        starting_counter = all_results.size # added this so it doesn't go through thousands of results
        responses.each do |response|
          # search specifically on State attribute
          response.attributes.each do |attribute|
            # todo - the line below works fine in ruby measure test, but not OS app.
            if (attribute.name.to_s == "State") and (attribute.valueAsString == state)
              all_results << response
            end
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
    site = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("site", choices_uid, choices_display,true)
    site.setDisplayName("Pick Colorado Site Component from the BCL.")
    args << site

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
    site = runner.getStringArgumentValue("site",user_arguments)

    if not site
      runner.registerError("No site component was selected.")
      return false
    end

    uid = site
    runner.registerInfo("uid is #{uid}")

    if uid.empty?
      runner.registerError("Error, could not find uid for #{site.valueAsString}.  Please try a different site component.")
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
    files = component.files("epw")
    if files.empty?
      runner.registerError("No epw file found")
      return false
    end
    epw_path = component.files("epw")[0]

    # parse epw file
    epw_file = OpenStudio::EpwFile.new(OpenStudio::Path.new(epw_path))

    # report initial condition of model
    if model.weatherFile.is_initialized and model.weatherFile.get.path.is_initialized
      runner.registerInitialCondition("Current weather file is #{model.weatherFile.get.path.get}")
    else
      runner.registerInitialCondition("The model doesn't have a weather file assigned.")
    end

    # get osc file
    osc_files = component.files("osc")
    if osc_files.empty?
      runner.registerError("No osc file found")
      return false
    end
    osc_path = component.files("osc")[0]
    osc_file = OpenStudio::IdfFile::load(osc_path)
    vt = OpenStudio::OSVersion::VersionTranslator.new
    component_object = vt.loadComponent(OpenStudio::Path.new(osc_path))

    # load os file
    if component_object.empty?
      runner.registerError("Cannot load construction component '#{osc_file}'")
      return false
    else
      object = component_object.get.primaryObject
      if object.to_Site.empty?
        runner.registerError("Component '#{osc_file}' does not include a site object")
        return false
      else
        componentData = model.insertComponent(component_object.get)
        if componentData.empty?
          runner.registerError("Failed to insert component '#{osc_file}' into model")
          return false
        else
          new_site_object = componentData.get.primaryComponentObject.to_Site.get
          runner.registerInfo("added site object named #{new_site_object.name}")
          site_water_main_temp = model.getSiteWaterMainsTemperature
          if site_water_main_temp.annualAverageOutdoorAirTemperature.is_initialized and site_water_main_temp.maximumDifferenceInMonthlyAverageOutdoorAirTemperatures.is_initialized
            avg_temp = site_water_main_temp.annualAverageOutdoorAirTemperature.get
            max_diff_monthly_avg_temp = site_water_main_temp.maximumDifferenceInMonthlyAverageOutdoorAirTemperatures.get
            avg_temp_ip = OpenStudio::convert(avg_temp,"C","F").get
            max_diff_monthly_avg_temp_ip = OpenStudio::convert(max_diff_monthly_avg_temp,"C","F").get
            runner.registerInfo("SiteWaterMainsTemperature object has Annual Avg. Outdoor Air Temp. of #{avg_temp_ip.round(2)} and Max. Diff. in Monthly Avg. Outdoor Air Temp. of #{max_diff_monthly_avg_temp_ip.round(2)}.")
          else
            runner.registerInfo("SiteWaterMainsTemperature object is missing Annual Avg. Outdoor Air Temp. or Max. Diff.in Monthly Avg. Outdoor Air Temp. set.")
          end
          runner.registerInfo("The model has #{model.getDesignDays.size} DesignDay objects")

        end
      end
    end

    # get epw file
    epw_files = component.files("epw")
    if files.empty?
      runner.registerError("No epw file found")
      return false
    end
    epw_path = component.files("epw")[0]

    # parse epw file
    epw_file = OpenStudio::EpwFile.new(OpenStudio::Path.new(epw_path))

    # set weather file (this sets path to BCL diretory vs. temp zip file without this)
    OpenStudio::Model::WeatherFile::setWeatherFile(model, epw_file)

    # report final condition of model
    if model.weatherFile.is_initialized and model.weatherFile.get.path.is_initialized
      runner.registerFinalCondition("Current weather file is #{model.weatherFile.get.path.get}")
    else
      runner.registerFinalCondition("The model doesn't have a weather file assigned.")
    end

    return true

  end
  
end

# register the measure to be used by the application
GetSiteFromBuildingComponentLibrary.new.registerWithApplication
