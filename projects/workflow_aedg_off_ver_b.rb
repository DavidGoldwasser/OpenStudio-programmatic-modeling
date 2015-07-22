# set constants
#MEASURES_ROOT_DIRECTORY = "measures"
MEASURES_ROOT_DIRECTORY = "../OpenStudio-measures/NREL working measures"
WEATHER_FILE_NAME = "USA_CO_Denver.Intl.AP.725650_TMY3.epw"
WEATHER_FILES_DIRECTORY = "weather"
SEED_FILE_NAME = "office_test_seed.osm"
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
  puts "Creating JSON and zip file for workflow option a"

  # jobs to run
  value_sets = populate_value_sets
  seed_model = "#{SEED_FILES_DIRECTORY}/#{SEED_FILE_NAME}"

  value_sets.each do |value_set|
    # create json files
    create_json(value_set,seed_model,"#{value_set[:hvac_type]}_#{value_set[:climate_zone]}")
  end
end

def workflow_create_models()
  puts "Creating JSON and zip file for workflow option a"

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
  value_sets << {:hvac_type => "AedgOfficeHvacAshpDoas", :climate_zone => "ASHRAE 169-2006-5B"}
  value_sets << {:hvac_type => "AedgOfficeHvacFanCoilDoas", :climate_zone => "ASHRAE 169-2006-5B"}
  value_sets << {:hvac_type => "AedgOfficeHvacRadiantDoas", :climate_zone => "ASHRAE 169-2006-5B"}
  value_sets << {:hvac_type => "AedgOfficeHvacVavChW", :climate_zone => "ASHRAE 169-2006-5B"}
  value_sets << {:hvac_type => "AedgOfficeHvacVavDx", :climate_zone => "ASHRAE 169-2006-5B"}
  value_sets << {:hvac_type => "AedgOfficeHvacWshpDoas", :climate_zone => "ASHRAE 169-2006-5B"}

  # todo - to support other climate zones I want to be able to change/set the constructions and loads in the seed model based on the climate zone

  return value_sets
end

# this defines the measures, and their argument values. It pulls from populate_value_sets as well as the constants defined at the beginning of the script
def populate_workflow(value_set,seed_model)

  # break out value_set
  hvac_type = value_set[:hvac_type]
  climate_zone = value_set[:climate_zone]
  area = 48000.0

  # setup
  measures = []

  # start of OpenStudio measures

  # adding assign_thermostats_basedon_standards_building_typeand_standards_space_type
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AssignThermostatsBasedonStandardsBuildingTypeandStandardsSpaceType')}"}

  # adding AEDG K12 measures that don't require arguments
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgSmallToMediumOfficeElectricEquipment')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgSmallToMediumOfficeElectricEquipmentControls')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgSmallToMediumOfficeInteriorLighting')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgSmallToMediumOfficeInteriorLightingControls')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgSmallToMediumOfficeExteriorWallConstruction')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgSmallToMediumOfficeRoofConstruction')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgSmallToMediumOfficeExteriorFloorConstruction')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgSmallToMediumOfficeExteriorDoorConstruction')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgSmallToMediumOfficeInteriorFinishes')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgSmallToMediumOfficeFenestrationAndDaylightingControls')}"}

  # adding AedgOfficeSwh
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  arguments << {:name => 'numberOfEmployees', :desc => 'Total Number of Employees.', :value => (area/200.0).to_i}
  measures << {
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgOfficeSwh')}",
      :arguments => arguments,
      :variables => variables
  }

  # adding AedgSmallToMediumOfficeEnvelopeAndEntryInfiltration
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  arguments << {:name => 'infiltrationEnvelope', :desc => 'Envelope Infiltration Level (Not including Occupant Entry Infiltration)', :value => "AEDG Small To Medium Office - Target"}
  arguments << {:name => 'infiltrationOccupant', :desc => 'Occupant Entry Infiltration Modeling Approach', :value => "Model Occupant Entry With a Vestibule if Recommended by Small to Medium Office AEDG"}
  arguments << {:name => 'story', :desc => 'Apply Occupant Entry Infiltration to ThermalZones on this floor.', :value => "Building Story 1"}
  measures << {
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgSmallToMediumOfficeEnvelopeAndEntryInfiltration')}",
      :arguments => arguments,
      :variables => variables
  }

  # adding AedgSmallToMediumOfficeExteriorLighting
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  arguments << {:name => 'target', :desc => 'Exterior Lighting Target Performance', :value => "AEDG SmMdOff - Target"}
  arguments << {:name => 'lightingZone', :desc => 'Exterior Lighting Zone', :value => "2 - Residential, Mixed Use"}
  arguments << {:name => 'facadeLandscapeLighting', :desc => 'Wall Coverage Area for Decorative Facade Lighting (ft^2)', :value => area*0.05} # todo - update to calc with aspect ratio and num floors
  arguments << {:name => 'parkingDrivesLighting', :desc => 'Ground Coverage Area for Parking Lots and Drives Lighting (ft^2)', :value => area*1.5}
  arguments << {:name => 'walkwayPlazaSpecialLighting', :desc => 'Ground Coverage Area for Walkway and Plaza Lighting (ft^2)', :value => area*0.1} # todo - update to calc with aspect ratio and num floors
  measures << {
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgSmallToMediumOfficeExteriorLighting')}",
      :arguments => arguments,
      :variables => variables
  }

  # use case statement to choose HVAC based on building type
  case hvac_type

    when "AedgOfficeHvacAshpDoas"

      # adding aedg_k12_hvac_dual_duct_doas
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

    when "AedgOfficeHvacFanCoilDoas"

      # adding aedg_k12_hvac_dual_duct_doas
      arguments = [] # :value is just a value
      variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
      arguments << {:name => 'ceilingReturnPlenumSpaceType', :desc => 'This space type should be part of a ceiling return air plenum.', :value => nil} # this is an optional argument
      arguments << {:name => 'costTotalHVACSystem', :desc => 'Total Cost for HVAC System ($).', :value => 0.0}
      arguments << {:name => 'remake_schedules', :desc => 'Apply recommended availability and ventilation schedules for air handlers?"', :value => true}
      measures << {
          :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgOfficeHvacFanCoilDoas')}",
          :arguments => arguments,
          :variables => variables
      }

    when "AedgOfficeHvacRadiantDoas"

      # adding aedg_k12_hvac_dual_duct_doas
      arguments = [] # :value is just a value
      variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
      arguments << {:name => 'ceilingReturnPlenumSpaceType', :desc => 'This space type should be part of a ceiling return air plenum.', :value => nil} # this is an optional argument
      arguments << {:name => 'costTotalHVACSystem', :desc => 'Total Cost for HVAC System ($).', :value => 0.0}
      arguments << {:name => 'remake_schedules', :desc => 'Apply recommended availability and ventilation schedules for air handlers?"', :value => true}
      measures << {
          :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgOfficeHvacRadiantDoas')}",
          :arguments => arguments,
          :variables => variables
      }

    when "AedgOfficeHvacVavChW"

      # adding aedg_k12_hvac_dual_duct_doas
      arguments = [] # :value is just a value
      variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
      arguments << {:name => 'ceilingReturnPlenumSpaceType', :desc => 'This space type should be part of a ceiling return air plenum.', :value => nil} # this is an optional argument
      arguments << {:name => 'costTotalHVACSystem', :desc => 'Total Cost for HVAC System ($).', :value => 0.0}
      arguments << {:name => 'remake_schedules', :desc => 'Apply recommended availability and ventilation schedules for air handlers?"', :value => true}
      measures << {
          :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgOfficeHvacVavChW')}",
          :arguments => arguments,
          :variables => variables
      }


    when "AedgOfficeHvacVavDx"

      # adding aedg_k12_hvac_dual_duct_doas
      arguments = [] # :value is just a value
      variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
      arguments << {:name => 'ceilingReturnPlenumSpaceType', :desc => 'This space type should be part of a ceiling return air plenum.', :value => nil} # this is an optional argument
      arguments << {:name => 'costTotalHVACSystem', :desc => 'Total Cost for HVAC System ($).', :value => 0.0}
      arguments << {:name => 'remake_schedules', :desc => 'Apply recommended availability and ventilation schedules for air handlers?"', :value => true}
      measures << {
          :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgOfficeHvacVavDx')}",
          :arguments => arguments,
          :variables => variables
      }

    when "AedgOfficeHvacWshpDoas"

      # adding aedg_k12_hvac_dual_duct_doas
      arguments = [] # :value is just a value
      variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
      arguments << {:name => 'ceilingReturnPlenumSpaceType', :desc => 'This space type should be part of a ceiling return air plenum.', :value => nil} # this is an optional argument
      arguments << {:name => 'costTotalHVACSystem', :desc => 'Total Cost for HVAC System ($).', :value => 0.0}
      arguments << {:name => 'remake_schedules', :desc => 'Apply recommended availability and ventilation schedules for air handlers?"', :value => true}
      measures << {
          :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgOfficeHvacWshpDoas')}",
          :arguments => arguments,
          :variables => variables
      }

    else

      # adding enable_ideal_air_loads_for_all_zones
      measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'EnableIdealAirLoadsForAllZones')}"}

  end

  # adding set_building_location
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  # this is for cloud run
  arguments << {:name => 'weather_directory', :desc => 'Weather Directory', :value => "../../weather"}
  # this is for local run
  # arguments << {:name => 'weather_directory', :desc => 'Weather Directory', :value => "../../../OpenStudio-programmatic-modeling/weather"}
  arguments << {:name => 'weather_file_name', :desc => 'Weather File Name', :value => WEATHER_FILE_NAME}
  measures << {
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'ChangeBuildingLocation')}",
      :arguments => arguments,
      :variables => variables
  }

  # start of energy plus measures

  #measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgSmallToMediumOfficeSlabAndBasement')}"}

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
  # disabled until server runs 1.7.5 or later
  #measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AnnualEndUseBreakdown')}"}

  return measures

end