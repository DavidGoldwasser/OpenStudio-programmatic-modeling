# set constants
MEASURES_ROOT_DIRECTORY = "measures"
WEATHER_FILE_NAME = "USA_CO_Denver.Intl.AP.725650_TMY3.epw"
WEATHER_FILES_DIRECTORY = "weather"
SEED_FILE_NAME = "secondary_school_geometry_only.osm"
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
  total_bldg_area_ip = value_set[:total_bldg_area_ip]

  # setup
  measures = []

  # start of OpenStudio measures

  # adding space_type_and_construction_set_wizard
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  arguments << {:name => 'buildingType', :desc => 'Building Type', :value => building_type}
  arguments << {:name => 'template', :desc => 'Template', :value => template}
  arguments << {:name => 'climateZone', :desc => 'Climate Zone', :value => climate_zone}
  arguments << {:name => 'createConstructionSet', :desc => 'Create Construction Set?', :value => true}
  arguments << {:name => 'setBuildingDefaults', :desc => 'Set Building Defaults Using New Objects?', :value => true}
  measures << {
      :name => 'space_type_and_construction_set_wizard',
      :desc => 'Space Type And Construction Set Wizard',
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'SpaceTypeAndConstructionSetWizard')}",
      :arguments => arguments,
      :variables => variables
  }

  # no measure to add envelope and fenestration, it is in the selected seed model.

  # adding assign_thermostats_basedon_standards_building_typeand_standards_space_type
  measures << {
      :name => 'assign_thermostats_basedon_standards_building_typeand_standards_space_type',
      :desc => 'Assign Thermostats Basedon Standards Building Typeand Standards Space Type',
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AssignThermostatsBasedonStandardsBuildingTypeandStandardsSpaceType')}",
      :variables => [],
      :arguments => []
  }

  # adding add_sys3_pszac
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  # currently runs on whole building, could add argument to specify their specific zone
  measures << {
      :name => 'add_sys3_pszac',
      :desc => 'Add Sys3 Pszac',
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AddSys3Pszac')}",
      :arguments => arguments,
      :variables => variables
  }

  # adding add_component_to_model (this adds a window construction and hooks it up to the construction sets in the model)
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  arguments << {:name => 'construction', :desc => 'Choose Construction Component to Import.', :value => "Interior Window"}
  measures << {
      :name => 'add_component_to_model',
      :desc => 'Add Component to Model',
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'add_component_to_model')}",
      :arguments => arguments,
      :variables => variables
  }

  # adding set_building_location
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  arguments << {:name => 'weather_directory', :desc => 'Weather Directory', :value => "../../weather"}
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
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'XcelEdaTariffSelectionandModelSetup')}",
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