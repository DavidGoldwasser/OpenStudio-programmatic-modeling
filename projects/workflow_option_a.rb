# description of workflow_option_a
# uses empty seed model
# runs space type and construction set wizard
# runs bar aspect ratio making building where all spaces use the default building space type
# adds fenestration
# adds thermostats
# adds ideal air loads or AEDG HVAC system depending on the building type
# add weather
# add Xcel tariff
# annual end use breakdown


# todo - objects to add or extend to analysis json process
# todo - output_variables
# todo - problem/algorithm/sample_method
# todo - problem/algorithm/number_of_samples
# todo - problem/algorithm/objective_functions
# todo - variables/uncertainty_description (need to extend for more fields)
# todo - analysis_type

# todo - add place to upload shared resources directory

# set constants
MEASURES_ROOT_DIRECTORY = "measures"
WEATHER_FILE_NAME = "USA_CO_Denver.Intl.AP.725650_TMY3.epw"
WEATHER_FILES_DIRECTORY = "weather"
SEED_FILE_NAME = "empty_seed.osm"
SEED_FILES_DIRECTORY = "seeds"

def workflow_create_jsons()
  puts "Creating JSON and zip file for workflow option a"

  # jobs to run
  value_sets = populate_value_sets
  seed_model = "#{SEED_FILES_DIRECTORY}/#{SEED_FILE_NAME}"

  value_sets.each do |value_set|
    # create json files
    create_json(value_set,seed_model,"#{value_set[:building_type]}_#{value_set[:template]}_#{value_set[:climate_zone]}")
  end
end

def workflow_create_models()
  puts "Creating JSON and zip file for workflow option a"

  # jobs to run
  value_sets = populate_value_sets
  seed_model = "#{SEED_FILES_DIRECTORY}/#{SEED_FILE_NAME}"

  value_sets.each do |value_set|
    # run measures and create model
    create_model(value_set,seed_model,"#{value_set[:building_type]}_#{value_set[:template]}_#{value_set[:climate_zone]}")
  end
end

# each entry here creates its own analysis. The values here are passed into populate_workflow
def populate_value_sets()
  # jobs to run
  value_sets = []
  value_sets << {:building_type => "Office", :template => "DOE Ref 2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0}
  value_sets << {:building_type => "LargeHotel", :template => "DOE Ref 2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0}
  value_sets << {:building_type => "Warehouse", :template => "DOE Ref 1980-2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0}
  value_sets << {:building_type => "SecondarySchool", :template => "DOE Ref 1980-2004", :climate_zone => "ASHRAE 169-2006-3A", :area => 50000.0}

  return value_sets
end

# this defines the measures, and their argument values. It pulls from populate_value_sets as well as the constants defined at the beginning of the script
def populate_workflow(value_set,seed_model)

  # break out value_set
  building_type = value_set[:building_type]
  template = value_set[:template]
  climate_zone = value_set[:climate_zone]
  total_bldg_area_ip = value_set[:area]

  # setup
  measures = []

  # start of OpenStudio measures

  # adding SpaceTypeAndConstructionSetWizard
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  arguments << {:name => 'buildingType', :desc => 'Building Type', :value => building_type}
  arguments << {:name => 'template', :desc => 'Template', :value => template}
  arguments << {:name => 'climateZone', :desc => 'Climate Zone', :value => climate_zone}
  arguments << {:name => 'createConstructionSet', :desc => 'Create Construction Set?', :value => true}
  arguments << {:name => 'setBuildingDefaults', :desc => 'Set Building Defaults Using New Objects?', :value => true}
  measures << {
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'SpaceTypeAndConstructionSetWizard')}",
      :arguments => arguments,
      :variables => variables
  }

  # adding BarAspectRatioStudy
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  arguments << {:name => 'total_bldg_area_ip', :desc => 'Total Building Floor Area (ft^2).', :value => total_bldg_area_ip}
  arguments << {:name => 'surface_matching', :desc => 'Surface Matching', :value => true}
  arguments << {:name => 'make_zones', :desc => 'Make Zones', :value => true}
  variables << {:name => 'ns_to_ew_ratio', :desc => 'Ratio of North/South Facade Length Relative to East/West Facade Length.', :value => {type: 'uniform', minimum: 0.2, maximum: 5.0, mean: 2.0, static_value: 2.0}}
  variables << {:name => 'num_floors', :desc => 'Number of Floors.', :value => {type: 'uniform', minimum: 1, maximum: 10, mean: 2, static_value: 2}}
  variables << {:name => 'floor_to_floor_height_ip', :desc => 'Floor to Floor Height.', :value => {type: 'uniform', minimum: 8, maximum: 20, mean: 10, static_value: 10}}
  measures << {
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'BarAspectRatioStudy')}",
      :arguments => arguments,
      :variables => variables
  }

  # populate hash for wwr measure
  wwr_hash = {}
  wwr_hash["North"] = {type: 'uniform', minimum: 0, maximum: 0.6, mean: 0.4, static_value: 0.4}
  wwr_hash["East"] = {type: 'uniform', minimum: 0, maximum: 0.6, mean: 0.15, static_value: 0.15}
  wwr_hash["South"] = {type: 'uniform', minimum: 0, maximum: 0.6, mean: 0.4, static_value: 0.4}
  wwr_hash["West"] = {type: 'uniform', minimum: 0, maximum: 0.6, mean: 0.15, static_value: 0.15}

  # loop through instances for wwr
  # note: measure description and variable names need to be unique for each instance
  wwr_hash.each do |facade,wwr|
    # adding bar_aspect_ratio_study
    arguments = [] # :value is just a value
    variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
    variables << {:name => 'wwr', :desc => "#{facade}|Window to Wall Ratio (fraction)", :value => wwr} # keep name unique if used as variable
    arguments << {:name => 'sillHeight', :desc => "Sill Height (in)", :value => 30.0}
    arguments << {:name => 'facade', :desc => 'Cardinal Direction.', :value => facade}
    measures << {
        :name => "#{facade.downcase}|set_window_to_wall_ratio_by_facade", #keep this snake_case with a "|" separating the unique prefix.
        :desc => "#{facade}|Set Window to Wall Ratio by Facade",
        :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'SetWindowToWallRatioByFacade')}",
        :arguments => arguments,
        :variables => variables
    }
  end

  # adding assign_thermostats_basedon_standards_building_typeand_standards_space_type
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AssignThermostatsBasedonStandardsBuildingTypeandStandardsSpaceType')}"}

  # use case statement to choose HVAC based on building type
  case building_type

    when "Office"

      # adding AedgOfficeHvacAshpDoas
      arguments = [] # :value is just a value
      variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
      arguments << {:name => 'ceilingReturnPlenumSpaceType', :desc => 'This space type should be part of a ceiling return air plenum.', :value => nil} # this is an optional argument
      arguments << {:name => 'costTotalHVACSystem', :desc => 'Total Cost for HVAC System ($).', :value => 0.0}
      arguments << {:name => 'remake_schedules', :desc => 'Apply recommended availability and ventilation schedules for air handlers?"', :value => true}
      measures << {
          :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgOfficeHvacAshpDoas')}",
          :arguments => arguments,
          :variables => variables
      }

    when "PrimarySchool" , "SecondarySchool"

      # adding AedgK12HvacDualDuctDoas
      arguments = [] # :value is just a value
      variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
      arguments << {:name => 'ceilingReturnPlenumSpaceType', :desc => 'This space type should be part of a ceiling return air plenum.', :value => nil} # this is an optional argument
      arguments << {:name => 'costTotalHVACSystem', :desc => 'Total Cost for HVAC System ($).', :value => 0.0}
      arguments << {:name => 'remake_schedules', :desc => 'Apply recommended availability and ventilation schedules for air handlers?"', :value => true}
      measures << {
          :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12HvacDualDuctDoas')}",
          :arguments => arguments,
          :variables => variables
      }

    else

      # adding EnableIdealAirLoadsForAllZones
      # this shows streamlined workflow item when no custom description and no arguments or variables
      measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'EnableIdealAirLoadsForAllZones')}"}

  end

  # adding ChangeBuildingLocation
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  arguments << {:name => 'weather_directory', :desc => 'Weather Directory', :value => "../../weather"}
  arguments << {:name => 'weather_file_name', :desc => 'Weather File Name', :value => WEATHER_FILE_NAME}
  measures << {
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'ChangeBuildingLocation')}",
      :arguments => arguments,
      :variables => variables
  }

  # start of energy plus measures

  # adding XcelEDATariffSelectionandModelSetup
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  arguments << {:name => 'elec_tar', :desc => 'Select an Electricity Tariff.', :value => "Secondary General"}
  arguments << {:name => 'gas_tar', :desc => 'Select a Gas Tariff.', :value => "Large CG"}
  measures << {
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'XcelEDATariffSelectionandModelSetup')}",
      :arguments => arguments,
      :variables => variables
  }

  # start of reporting measures

  # adding annual_end_use_breakdown
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AnnualEndUseBreakdown')}"}

  return measures

end