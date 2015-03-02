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

  # this argument wants a string that it will convert to a hash
  space_type_fraction = "{
    :DOE Ref 2004 - Office - Corridor => '0.3',
    :DOE Ref 2004 - Office - Conference => '0.2',
    :DOE Ref 2004 - Office - ClosedOffice => '0.5'
  }"
  value_sets << {:building_type => "Office", :template => "DOE Ref 2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0, :space_type_fraction => space_type_fraction.gsub("\n","").gsub("\t","")}

  space_type_fraction = "{
    :DOE Ref 2004 - LrgHotel - GuestRoom => '0.5',
    :DOE Ref 2004 - LrgHotel - Corridor => '0.2',
    :DOE Ref 2004 - LrgHotel - Kitchen => '0.05',
    :DOE Ref 2004 - LrgHotel - Lobby => '0.25'
  }"
  value_sets << {:building_type => "LargeHotel", :template => "DOE Ref 2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0, :space_type_fraction => space_type_fraction.gsub("\n","").gsub("\t","")}

  space_type_fraction = "{
    :DOE Ref 1980-2004 - Warehouse - Bulk => '0.75',
    :DOE Ref 1980-2004 - Warehouse - Fine => '0.2',
    :DOE Ref 1980-2004 - Warehouse - Office => '0.05'
  }"
  value_sets << {:building_type => "Warehouse", :template => "DOE Ref 1980-2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0, :space_type_fraction => space_type_fraction.gsub("\n","").gsub("\t","")}

  space_type_fraction = "{
    :DOE Ref 1980-2004 - SecSchl - Classroom => '0.5',
    :DOE Ref 1980-2004 - SecSchl - Corridor => '0.2',
    :DOE Ref 1980-2004 - SecSchl - Cafeteria => '0.1',
    :DOE Ref 1980-2004 - SecSchl - Office => '0.1',
    :DOE Ref 1980-2004 - SecSchl - Lobby => '0.1'
  }"
  value_sets << {:building_type => "SecondarySchool", :template => "DOE Ref 1980-2004", :climate_zone => "ASHRAE 169-2006-3A", :area => 50000.0, :space_type_fraction => space_type_fraction.gsub("\n","").gsub("\t","")}

  return value_sets
end

# this defines the measures, and their argument values. It pulls from populate_value_sets as well as the constants defined at the beginning of the script
def populate_workflow(value_set,seed_model)

  # break out value_set
  building_type = value_set[:building_type]
  template = value_set[:template]
  climate_zone = value_set[:climate_zone]
  total_bldg_area_ip = value_set[:total_bldg_area_ip]
  space_type_fraction = value_set[:space_type_fraction]

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
  variables << {:name => 'ns_to_ew_ratio', :desc => 'Ratio of North/South Facade Length Relative to East/West Facade Length.', :value => {type: 'uniform', minimum: 0.2, maximum: 5.0, mean: 2.0, static_value: 2.0}}
  variables << {:name => 'num_floors', :desc => 'Number of Floors.', :value => {type: 'uniform', minimum: 1, maximum: 10, mean: 2, static_value: 2}}
  variables << {:name => 'floor_to_floor_height_ip', :desc => 'Floor to Floor Height.', :value => {type: 'uniform', minimum: 8, maximum: 20, mean: 10, static_value: 10}}
  arguments << {:name => 'spaceTypeHashString', :desc => 'Hash of Space Types with Name as Key and Fraction as value.', :value => space_type_fraction}
  measures << {
      :name => 'bar_aspect_ratio_sliced_by_space_type',
      :desc => 'Bar Aspect Ratio Sliced by Space Type',
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'BarAspectRatioSlicedBySpaceType')}",
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

puts "running workflow option b"

# jobs to run
value_sets = populate_value_sets
seed_model = "#{SEED_FILES_DIRECTORY}/#{SEED_FILE_NAME}"

value_sets.each do |value_set|
  # create json files
  create_json(value_set,seed_model,"#{value_set[:building_type]}_#{value_set[:template]}_#{value_set[:climate_zone]}")

  # run measures and create model
  create_model(value_set,seed_model,"#{value_set[:building_type]}_#{value_set[:template]}_#{value_set[:climate_zone]}")
end
