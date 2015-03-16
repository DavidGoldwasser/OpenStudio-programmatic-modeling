# set constants
#MEASURES_ROOT_DIRECTORY = "measures"
MEASURES_ROOT_DIRECTORY = "../OpenStudio-measures/NREL working measures"
WEATHER_FILE_NAME = "USA_CO_Denver.Intl.AP.725650_TMY3.epw"
WEATHER_FILES_DIRECTORY = "weather"
SEED_FILE_NAME = "secondary_school_space_attributes.osm"
SEED_FILES_DIRECTORY = "seeds"

def workflow_create_jsons()
  puts "Creating JSON and zip file for workflow option a"

  # jobs to run
  value_sets = populate_value_sets
  seed_model = "#{SEED_FILES_DIRECTORY}/#{SEED_FILE_NAME}"

  value_sets.each do |value_set|
    # create json files
    create_json(value_set,seed_model,"#{value_set[:building_type]}_#{value_set[:climate_zone]}")
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
  value_sets << {:hvac_type => "AedgK12HvacDualDuctDoas", :climate_zone => "ASHRAE 169-2006-3A"}

  return value_sets
end

# this defines the measures, and their argument values. It pulls from populate_value_sets as well as the constants defined at the beginning of the script
def populate_workflow(value_set,seed_model)

  # break out value_set
  hvac_type = value_set[:hvac_type]
  climate_zone = value_set[:climate_zone]

  # setup
  measures = []

  # start of OpenStudio measures

  # adding AEDG K12 measures
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12ElectricEquipment')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12ElectricEquipmentControls')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12EnvelopeAndEntryInfiltration')}"}
  # measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12ExteriorDoorConstruction')}"} # todo had issues resolving matched surfaces
  # measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12ExteriorFloorConstruction')}"}
  # measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12ExteriorWallConstruction')}"}
  # measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12RoofConstruction')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12FenestrationAndDaylightingControls')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12InteriorFinishes')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12InteriorLighting')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12InteriorLightingControls')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12Kitchen')}"}
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12Swh')}"}

  # need to supply inputs
  #measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12ExteriorLighting')}"}

  #measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12SlabAndBasement')}"}


  # use case statement to choose HVAC based on building type
  case hvac_type

    when "AedgK12HvacDualDuctDoas"

      # adding aedg_k12_hvac_dual_duct_doas
      arguments = [] # :value is just a value
      variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
      arguments << {:name => 'ceilingReturnPlenumSpaceType', :desc => 'This space type should be part of a ceiling return air plenum.', :value => nil} # this is an optional argument
      arguments << {:name => 'costTotalHVACSystem', :desc => 'Total Cost for HVAC System ($).', :value => 0.0}
      arguments << {:name => 'remake_schedules', :desc => 'Apply recommended availability and ventilation schedules for air handlers?"', :value => true}
      measures << {
          :name => 'aedg_k12_hvac_dual_duct_doas',
          :desc => 'AEDG K12 Hvac Dual Duct Doas',
          :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgK12HvacDualDuctDoas')}",
          :arguments => arguments,
          :variables => variables
      }

    else

      # adding enable_ideal_air_loads_for_all_zones
      measures << {
          :name => 'enable_ideal_air_loads_for_all_zones',
          :desc => 'Enable Ideal Air Loads For All Zones',
          :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'EnableIdealAirLoadsForAllZones')}",
          :variables => [],
          :arguments => []
      }

  end

  # adding set_building_location
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  #arguments << {:name => 'weather_directory', :desc => 'Weather Directory', :value => "../../weather"}
  arguments << {:name => 'weather_directory', :desc => 'Weather Directory', :value => "../../../OpenStudio-programmatic-modeling/weather"}
  arguments << {:name => 'weather_file_name', :desc => 'Weather File Name', :value => WEATHER_FILE_NAME}
  measures << {
      :name => 'change_building_location',
      :desc => 'Change Building Location And Design Days',
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'ChangeBuildingLocation')}",
      :arguments => arguments,
      :variables => variables
  }

  # start of energy plus measures

  # adding xcel_eda_tariff_selectionand_model_setup
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  arguments << {:name => 'elec_tar', :desc => 'Select an Electricity Tariff.', :value => "Secondary General"}
  arguments << {:name => 'gas_tar', :desc => 'Select a Gas Tariff.', :value => "Large CG"}
  measures << {
      :name => 'xcel_eda_tariff_selectionand_model_setup',
      :desc => 'Xcel EDA Tariff Selectionand Model Setup',
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'XcelEDATariffSelectionandModelSetup')}",
      :arguments => arguments,
      :variables => variables
  }


  # start of reporting measures

  # adding annual_end_use_breakdown
  measures << {
      :name => 'annual_end_use_breakdown',
      :desc => 'Annual End Use Breakdown',
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AnnualEndUseBreakdown')}",
      :variables => [],
      :arguments => []
  }

  return measures

end