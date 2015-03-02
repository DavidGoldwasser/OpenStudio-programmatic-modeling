def create_json(building_type, template, climate_zone, total_bldg_area_ip,seed_model)

  measures = populate_workflow(building_type, template, climate_zone, total_bldg_area_ip,seed_model)

  # populate outputs
  outputs = [
      {}
  ]

  weather_files = [
      "#{WEATHER_FILES_DIRECTORY}/*"
  ]
  default_weather_file = "#{WEATHER_FILES_DIRECTORY}/#{WEATHER_FILE_NAME}"

  # define path to seed model
  seed_model = seed_model

  # save path
  save_string = "#{building_type}_#{template}_#{climate_zone}"

  # configure analysis
  a = OpenStudio::Analysis.create(save_string)

  # add measures to analysis
  measures.each do |m|
    measure = a.workflow.add_measure_from_path(m[:name], m[:desc], m[:path])
    m[:arguments].each do |a|
      measure.argument_value(a[:name], a[:value])
    end
    m[:variables].each do |v|
      measure.make_variable(v[:name], v[:desc], v[:value])
    end
  end

  # add output to analysis
  outputs.each do |o|
    a.add_output(o)
  end

  # add weather files to analysis
  weather_files.each do |p|
    a.weather_files.add_files(p)
  end

  # make sure to set the default weather file as well
  a.weather_file(default_weather_file)

  # seed model
  a.seed_model(seed_model)

  # add in the other libraries
  # use this if the measures have shared resources
  #a.libraries.add("#{MEASURES_ROOT_DIRECTORY}/lib", { library_name: 'lib'})

  # Save the analysis JSON
  formulation_file = "analysis/#{save_string.downcase.squeeze(' ').gsub(' ', '_')}.json"
  zip_file = "analysis/#{save_string.downcase.squeeze(' ').gsub(' ', '_')}.zip"

  # set the analysis type here as well.
  a.analysis_type = ANALYSIS_TYPE

  # save files
  a.save formulation_file
  a.save_zip zip_file

end

def create_model(building_type, template, climate_zone, total_bldg_area_ip,seed_model)

  measures = populate_workflow(building_type, template, climate_zone, total_bldg_area_ip,seed_model)

  # todo - to accommodate measures with string/path arguments it would be better for this section to run on the contents of the zip file. Then paths would match what happens on the server.

  # define path to seed model
  seed_model = seed_model

  # add in necessary requires (these used to be at the top but should work here)
  require 'openstudio'
  require 'openstudio/ruleset/ShowRunnerOutput'

  # create an instance of a runner
  runner = OpenStudio::Ruleset::OSRunner.new

  # load the test model
  translator = OpenStudio::OSVersion::VersionTranslator.new
  path = OpenStudio::Path.new("#{Dir.pwd}/#{seed_model}")
  model = translator.loadModel(path)

  # confirm that model was opened
  if not model.empty?
    model = model.get
    puts "Opening #{seed_model}"
  else
    puts "Couldn't open seed model, creating a new empty model"
    model = OpenStudio::Model::Model.new
  end

  # add measures to analysis
  measures.each do |m|

    # load the measure
    require_relative (Dir.pwd + "/" + m[:path] + "/measure.rb")

    # infer class from name
    name_without_prefix = m[:name].split("|")
    measure_class = "#{name_without_prefix.last}".split('_').collect(&:capitalize).join

    # create an instance of the measure
    measure = eval(measure_class).new

    # skip from this loop if it is an E+ or Reporting measure
    if not measure.is_a?(OpenStudio::Ruleset::ModelUserScript)
      puts "Skipping #{measure.name}. It isn't a model measure."
      next
    end

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # get argument values
    args_hash = {}
    m[:arguments].each do |a|
      args_hash[a[:name]] = a[:value]
    end
    m[:variables].each do |v|
      # todo - add logic to use something other than static value when argument is variable
      args_hash[v[:name]] = v[:value][:static_value]
    end

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        temp_arg_var.setValue(args_hash[arg.name])
      end
      argument_map[arg.name] = temp_arg_var
    end

    # just added as test of where measure is running from
    #puts "Measure is running from #{Dir.pwd}"

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    end

    # save path
    save_string = "#{building_type}_#{template}_#{climate_zone}"
    output_file_path = OpenStudio::Path.new("analysis_local/#{save_string}.osm")
    puts "Saving #{output_file_path}"
    model.save(output_file_path,true)

    # todo - look at ChnageBuildingLocation, it things it is in files, not weather? Can I save the folder like app does

    # todo - add support for E+ and reporting measures (will require E+ run)

end

# Command-line arguments in Rake: http://viget.com/extend/protip-passing-parameters-to-your-rake-tasks
def get_scripts(script = '')
  # If excel_file is not pre-specified, request it as input
  unless script && !script.empty?
    # Determine the project file to run.  This will list out all the xlsx files and give you a
    # choice from which to choose
    puts
    puts 'Select which project to run from the list below:'.cyan.underline
    puts 'Note: if this list is too long, simply remove .rb files from the ./projects directory'.cyan
    projects = Dir.glob('./projects/*.rb').reject { |i| i =~ /~\$.*/ }
    projects.each_index do |i|
      puts "  #{i + 1}) #{File.basename(projects[i])}".green
    end
    puts
    print "Selection (1-#{projects.size}): ".cyan
    n = $stdin.gets.chomp
    n_i = n.to_i
    if n_i == 0 || n_i > projects.size
      puts "Could not process your selection. You entered '#{n}'".red
      exit
    end

    script = projects[n_i - 1]
  end

  # run it
  path = "../../#{script}"
  puts "Running #{path}"
  require_relative("#{path}")

end

# todo - for now this is needed for workflow:queue, but ideally we can get rid of that.
def populate_value_sets()
  # jobs to run
  value_sets = []
  value_sets << {:building_type => "Office", :template => "DOE Ref 2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0}
  value_sets << {:building_type => "LargeHotel", :template => "DOE Ref 2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0}
  value_sets << {:building_type => "Warehouse", :template => "DOE Ref 1980-2004", :climate_zone => "ASHRAE 169-2006-5B", :area => 50000.0}
  value_sets << {:building_type => "SecondarySchool", :template => "DOE Ref 1980-2004", :climate_zone => "ASHRAE 169-2006-3A", :area => 50000.0}

  return value_sets
end


namespace :workflow do

  # set constants
  ANALYSIS_TYPE = 'single_run'
  HOSTNAME = 'http://localhost:8080'

  desc 'make analysis jsons from specified workflow script'
  task :make_jsons do
    script = get_scripts
  end

  #create_json(structure_id, building_type, year, system_type)
=begin
  desc 'run create_model script'
  task :models do

    # jobs to run
    value_sets = populate_value_sets
    seed_model = "#{SEED_FILES_DIRECTORY}/#{SEED_FILE_NAME}"

    value_sets.each do |value_set|
      create_model(value_set[:building_type], value_set[:template], value_set[:climate_zone], value_set[:total_bldg_area_ip],seed_model)
    end

  end
=end

  desc 'queue the jsons'
  task :queue do

    # todo - update this to loop through jsons in the analysis directory instead of replying on populate_value_sets

    # jobs to run
    value_sets = populate_value_sets

    value_sets.each do |value_set|
      save_string = "#{value_set[:building_type]}_#{value_set[:template]}_#{value_set[:climate_zone]}"
      save_string_cleaned = save_string.downcase.gsub(' ','_')

      formulation_file = "analysis/#{save_string_cleaned}.json"
      zip_file = "analysis/#{save_string_cleaned}.zip"
      if File.exist?(formulation_file) && File.exist?(zip_file)
        puts "Running #{save_string_cleaned}"
        api = OpenStudio::Analysis::ServerApi.new( { hostname: HOSTNAME } )
        api.queue_single_run(formulation_file, zip_file, ANALYSIS_TYPE)
      else
        puts "Could not file JSON or ZIP for #{save_string_cleaned}"
      end
    end

  end

  desc 'start the run queue'
  task :start do
    api = OpenStudio::Analysis::ServerApi.new( { hostname: HOSTNAME } )
    api.run_batch_run_across_analyses(nil, nil, ANALYSIS_TYPE)
  end

end