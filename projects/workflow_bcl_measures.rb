# description of workflow_bcl_measures (testing measures that hit search BCL in arguments, and download in run section)
# uses custom seed model with school geometry
# runs space type and construction set wizard
# adds thermostats
# adding AddSys3PSZAC
# Get construction from BCL and add it to the model. Ideally self populate possible choices. Don't think I'll do that for now
# Get site object from BCL, and add to model. It includes site object, design days, water main temps, and weather file
# add Xcel tariff
# annual end use breakdown

# set constants
MEASURES_ROOT_DIRECTORY = "measures"
WEATHER_FILES_DIRECTORY = "weather"
SEED_FILE_NAME = "secondary_school_geometry_only.osm"
SEED_FILES_DIRECTORY = "seeds"

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
  value_sets << {:building_type => "Office", :template => "DOE Ref 2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0, :ext_wal_type => "Mass"}
  value_sets << {:building_type => "LargeHotel", :template => "DOE Ref 2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0, :ext_wal_type => "Mass"}
  value_sets << {:building_type => "Warehouse", :template => "DOE Ref 1980-2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0, :ext_wal_type => "SteelFrame"}
  value_sets << {:building_type => "SecondarySchool", :template => "DOE Ref 1980-2004", :climate_zone => "ASHRAE 169-2006-3A", :area => 50000.0, :ext_wal_type => "SteelFrame"}

  return value_sets
end

# this defines the measures, and their argument values. It pulls from populate_value_sets as well as the constants defined at the beginning of the script
def populate_workflow(value_set,seed_model)

  # break out value_set
  building_type = value_set[:building_type]
  template = value_set[:template]
  climate_zone = value_set[:climate_zone]
  total_bldg_area_ip = value_set[:area]
  ext_wall_type = value_set[:ext_wall_type]

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

  # get_exterior_wall_construction_from_bcl (note, climate zone should be set prior to this if not in seed model)
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  # todo - update this to be variable, choices will vary by exterior wall type
  if ext_wall_type == "Mass"
    arguments << {:name => 'construction', :desc => 'Pick An Exterior Wall Construction from BCL.', :value => "189.1-2009 Nonres 5B Ext Wall Mass"}
  elsif ext_wall_type == "SteelFrame"
    arguments << {:name => 'construction', :desc => 'Pick An Exterior Wall Construction from BCL.', :value => "189.1-2009 Nonres 5B Ext Wall Steel-Framed"}
  else
    puts "unexpected value"
  end
  measures << {
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'get_exterior_wall_construction_from_bcl')}",
      :arguments => arguments,
      :variables => variables
  }

  # get_site_from_building_component_library
  arguments = [] # :value is just a value
  variables = [] # :value needs to be a hash {type: nil,  minimum: nil, maximum: nil, mean: nil, status_value: nil}
  # todo - update site to be a variable (Denver-Stapleton CO [724690 TMY--23062] Site, BOULDER CO [724699 TMY2-94018] Site, Akron Washington Co Ap CO [724698 TMY3] Site)
  arguments << {:name => 'site', :desc => 'Pick Colorado Site Component from the BCL', :value => "Denver-Stapleton CO [724690 TMY--23062] Site"}
  measures << {
      :path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'get_site_from_building_component_library')}",
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
  measures << {:path => "#{File.join(MEASURES_ROOT_DIRECTORY, 'AnnualEndUseBreakdown')}"}

  return measures

end