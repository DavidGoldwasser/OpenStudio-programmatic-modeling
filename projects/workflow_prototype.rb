# set constants
#MEASURES_ROOT_DIRECTORY = "measures"
MEASURES_ROOT_DIRECTORY = "../OpenStudio-Prototype-Buildings"
WEATHER_FILE_NAME = "USA_CO_Denver.Intl.AP.725650_TMY3.epw"
WEATHER_FILES_DIRECTORY = "weather"
SEED_FILE_NAME = "empty_seed.osm"
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
  puts "Creating JSON and zip file for prototype testing workflow"

  # jobs to run
  value_sets = populate_value_sets
  seed_model = "#{SEED_FILES_DIRECTORY}/#{SEED_FILE_NAME}"

  value_sets.each do |value_set|
    # create json files
    create_json(value_set,seed_model,"#{value_set[:hvac_type]}_#{value_set[:climate_zone]}")
  end
end

def workflow_create_models()
  puts "Creating model for prototype testing workflow"

  # jobs to run
  value_sets = populate_value_sets
  seed_model = "#{SEED_FILES_DIRECTORY}/#{SEED_FILE_NAME}"

  value_sets.each do |value_set|
    # run measures and create model
    create_model(value_set,seed_model,"#{value_set[:hvac_type]}_#{value_set[:climate_zone]}")
  end
end

# each entry here creates its own analysis. The values here are passed into populate_workflow
def populate_value_sets()
  # jobs to run
  value_sets = []
  value_sets << {:climate_zone => "ASHRAE 169-2006-5A"}
  return value_sets
end

# this defines the measures, and their argument values. It pulls from populate_value_sets as well as the constants defined at the beginning of the script
def populate_workflow(value_sets,seed_model)

  # value_sets not used

  # setup
  measures = []

  # start of OpenStudio measures

  # adding create_DOE_prototype_building
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  # todo change to variables
  arguments << {:name => 'building_type', :desc => 'Select a Building Type', :value => 'SecondarySchool'}
  arguments << {:name => 'building_vintage', :desc => 'Select a Vintage', :value => '90.1-2010'}
  arguments << {:name => 'climate_zone', :desc => 'Select a Climate Zone', :value => 'ASHRAE 169-2006-5A'}
  measures << {
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'create_DOE_prototype_building')}",
      :arguments => arguments,
      :variables => variables
  }

  # start of energy plus measures


  # start of reporting measures


  # todo - create and add in compare_results measure


  # todo - adding annual_end_use_breakdown
  # disabled until server runs 1.7.5 or later
  #measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AnnualEndUseBreakdown')}"}

  return measures

end