# description of workflow_option_c
# uses custom seed model with school geometry
# runs space type and construction set wizard
# adds thermostats
# adding AddSys3PSZAC
# add sub surface construction component to the model from local resources directory
# add weather
# add Xcel tariff
# annual end use breakdown

# set constants
MEASURES_ROOT_DIRECTORY = "measures"
WEATHER_FILE_NAME = "USA_CO_Denver.Intl.AP.725650_TMY3.epw"
WEATHER_FILES_DIRECTORY = "weather"
SEED_FILE_NAME = "secondary_school_geometry_only.osm"
SEED_FILES_DIRECTORY = "seeds"
OUTPUTS = []
ANALYSIS_TYPE = 'single_run' # valid options [batch_run,lhs,optim,regenoud,nsga_nrel,preflight,sequential_search,single_run]
SAMPLE_METHOD = 'all_variables' # valid options [individual_variables,all_variables]
NUMBER_OF_SAMPLES = 1 # valid options are any positive integer

# populate outputs
OUTPUTS << {
    display_name: 'Total Natural Gas Intensity',
    display_short_name: 'NG EUI',
    name: 'standard_report_legacy.total_natural_gas',
    units: 'MJ/m2',
    objective_function: true,
    objective_function_target: 140.0,
    visualize: true,
    export: true
}
OUTPUTS << {
    display_name: 'Total Electricity Intensity',
    display_short_name: 'Elec EUI',
    name: 'standard_report_legacy.total_electricity',
    units: 'MJ/m2',
    objective_function: true,
    objective_function_target: 590.0,
    scaling_factor: 5.0,
    visualize: true,
    export: true
}
OUTPUTS << {
    display_name: 'Unmet Cooling Hours',
    display_short_name: 'Unmet Cooling Hours',
    name: 'standard_report_legacy.time_setpoint_not_met_during_occupied_cooling',
    units: 'hrs',
    objective_function: true,
    visualize: true,
    export: true
}
OUTPUTS << {
    display_name: 'Unmet Heating Hours',
    display_short_name: 'Unmet Heating Hours',
    name: 'standard_report_legacy.time_setpoint_not_met_during_occupied_heating',
    units: 'hrs',
    objective_function: true,
    visualize: true,
    export: true
}

def workflow_create_jsons()
  puts "Creating JSON and zip file for workflow option c"

  # jobs to run
  value_sets = populate_value_sets
  seed_model = "#{SEED_FILES_DIRECTORY}/#{SEED_FILE_NAME}"

  value_sets.each do |value_set|
    # create json files
    create_json(value_set,seed_model,"#{value_set[:building_type]}_#{value_set[:template]}_#{value_set[:climate_zone]}")
  end
end

def workflow_create_models()
  puts "Creating JSON and zip file for workflow option c"

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

  # no measure to add envelope and fenestration, it is in the selected seed model.

  # adding AssignThermostatsBasedonStandardsBuildingTypeandStandardsSpaceType
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AssignThermostatsBasedonStandardsBuildingTypeandStandardsSpaceType')}"}

  # adding AddSys3PSZAC
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AddSys3PSZAC')}"}

  # adding add_component_to_model (this adds a window construction and hooks it up to the construction sets in the model)
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  arguments << {:name => 'construction', :desc => 'Choose Construction Component to Import.', :value => "Interior Window"}
  measures << {
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'add_component_to_model')}",
      :arguments => arguments,
      :variables => variables
  }

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

  # adding AnnualEndUseBreakdown
  # measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AnnualEndUseBreakdown')}"}

  return measures

end