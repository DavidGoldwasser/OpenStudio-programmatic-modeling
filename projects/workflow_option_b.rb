# set constants
MEASURES_ROOT_DIRECTORY = "measures"
WEATHER_FILE_NAME = "USA_CO_Denver.Intl.AP.725650_TMY3.epw"
WEATHER_FILES_DIRECTORY = "weather"
SEED_FILE_NAME = "empty_seed.osm"
SEED_FILES_DIRECTORY = "seeds"

# each entry here creates its own analysis. The values here are passed into populate_workflow
def populate_value_sets()
  # jobs to run
  value_sets = []
  value_sets << {:building_type => "Office", :template => "DOE Ref 2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0}
  value_sets << {:building_type => "LargeHotel", :template => "DOE Ref 2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0}
  #value_sets << {:building_type => "Warehouse", :template => "DOE Ref 1980-2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0}
  #value_sets << {:building_type => "SecondarySchool", :template => "DOE Ref 1980-2004", :climate_zone => "ASHRAE 169-2006-3A", :area => 50000.0}

  return value_sets
end

# this defines the measures, and their argument values. It pulls from populate_value_sets as well as the constants defined at the beginning of the script
def populate_workflow(building_type, template, climate_zone, total_bldg_area_ip,seed_model)

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

  # adding bar_aspect_ratio_study
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  arguments << {:name => 'total_bldg_area_ip', :desc => 'Total Building Floor Area (ft^2).', :value => total_bldg_area_ip}
  arguments << {:name => 'surface_matching', :desc => 'Surface Matching', :value => true}
  arguments << {:name => 'make_zones', :desc => 'Make Zones', :value => true}
  variables << {:name => 'ns_to_ew_ratio', :desc => 'Ratio of North/South Facade Length Relative to East/West Facade Length.', :value => {type: 'uniform', minimum: 0.2, maximum: 5.0, mean: 2.0, static_value: 2.0}}
  variables << {:name => 'num_floors', :desc => 'Number of Floors.', :value => {type: 'uniform', minimum: 1, maximum: 10, mean: 2, static_value: 2}}
  variables << {:name => 'floor_to_floor_height_ip', :desc => 'Floor to Floor Height.', :value => {type: 'uniform', minimum: 8, maximum: 20, mean: 10, static_value: 10}}
  measures << {
      :name => 'bar_aspect_ratio_study',
      :desc => 'Bar Aspect Ratio Study',
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'BarAspectRatioStudy')}",
      :arguments => arguments,
      :variables => variables
  }

  # adding assign_thermostats_basedon_standards_building_typeand_standards_space_type
  measures << {
      :name => 'assign_thermostats_basedon_standards_building_typeand_standards_space_type',
      :desc => 'Assign Thermostats Basedon Standards Building Typeand Standards Space Type',
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AssignThermostatsBasedonStandardsBuildingTypeandStandardsSpaceType')}",
      :variables => [],
      :arguments => []
  }

  # use case statement to choose HVAC based on building type
  case building_type

    when "Office"

      # adding aedg_office_hvac_ashp_doas
      arguments = [] # :value is just a value
      variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
      arguments << {:name => 'ceilingReturnPlenumSpaceType', :desc => 'This space type should be part of a ceiling return air plenum.', :value => nil} # this is an optional argument
      arguments << {:name => 'costTotalHVACSystem', :desc => 'Total Cost for HVAC System ($).', :value => 0.0}
      arguments << {:name => 'remake_schedules', :desc => 'Apply recommended availability and ventilation schedules for air handlers?"', :value => true}
      measures << {
          :name => 'aedg_office_hvac_ashp_doas',
          :desc => 'AEDG Office Hvac Ashp Doas',
          :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AedgOfficeHvacAshpDoas')}",
          :arguments => arguments,
          :variables => variables
      }

    when "PrimarySchool" , "SecondarySchool"

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

  # start of reporting measures

end

puts "running workflow option b"
# todo - run method to make jsons using data from this script

# jobs to run
value_sets = populate_value_sets
seed_model = "#{SEED_FILES_DIRECTORY}/#{SEED_FILE_NAME}"

value_sets.each do |value_set|
  # create json files
  create_json(value_set[:building_type], value_set[:template], value_set[:climate_zone], value_set[:total_bldg_area_ip],seed_model)

  # run measures and create model
  create_model(value_set[:building_type], value_set[:template], value_set[:climate_zone], value_set[:total_bldg_area_ip],seed_model)
end