# this will create json and zip file from scripts in projects directory
def create_json(value_set,seed_model,save_string)

  measures = populate_workflow(value_set,seed_model)

  # populate outputs
  outputs = [
      {display_name: 'Total Natural Gas Intensity', display_short_name: 'NG EUI', name: 'standard_report_legacy.total_natural_gas', units: 'MJ/m2', objective_function: true, objective_function_target: 140.0, visualize: true, export: true},
      {display_name: 'Total Electricity Intensity', display_short_name: 'Elec EUI', name: 'standard_report_legacy.total_electricity', units: 'MJ/m2', objective_function: true, objective_function_target: 590.0, scaling_factor: 5.0, visualize: true, export: true},
      {display_name: 'Unmet Cooling Hours', display_short_name: 'Unmet Cooling Hours', name: 'standard_report_legacy.time_setpoint_not_met_during_occupied_cooling', units: 'hrs', objective_function: true, visualize: true, export: true},
      {display_name: 'Unmet Heating Hours', display_short_name: 'Unmet Heating Hours', name: 'standard_report_legacy.time_setpoint_not_met_during_occupied_heating', units: 'hrs', objective_function: true, visualize: true, export: true},
  ]

  weather_files = [
      "#{WEATHER_FILES_DIRECTORY}/*"
  ]
  default_weather_file = "#{WEATHER_FILES_DIRECTORY}/#{WEATHER_FILE_NAME}"

  # configure analysis
  a = OpenStudio::Analysis.create(save_string)

  # add measures to analysis
  measures.each do |m|

    # load the measure.json file
    path_to_measure_json =  (Dir.pwd + "/" + m[:path] + "/measure.json")
    measure_json = JSON.parse(File.read(path_to_measure_json))

    # get name and description from measure.json if it doesn't already exist
    if not m[:name]
      m[:name] = measure_json["name"]
    end
    if not m[:description]
      m[:description] = measure_json["description"]
    end

    # make empty array for arguments and variables if not passed in
    if not m[:arguments]
      m[:arguments] = []
    end
    if not m[:variables]
      m[:variables] = []
    end

    measure = a.workflow.add_measure_from_path(m[:name], m[:desc], m[:path])
    m[:arguments].each do |a|
      if a[:value].is_a?(Hash)
        measure.argument_value(a[:name], a[:value][:static_value])
      else
        measure.argument_value(a[:name], a[:value])
      end
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
  a.libraries.add("lib/resources", { library_name: 'resources'})

  # Save the analysis JSON
  formulation_file = "analysis/#{save_string.downcase.squeeze(' ').gsub(' ', '_')}/#{save_string.downcase.squeeze(' ').gsub(' ', '_')}.json"
  zip_file = "analysis/#{save_string.downcase.squeeze(' ').gsub(' ', '_')}/#{save_string.downcase.squeeze(' ').gsub(' ', '_')}.zip"

  # set the analysis attributes here
  # todo - add code to overwrite defaults with settings from selected workflow script
  a.analysis_type = ANALYSIS_TYPE
  a.algorithm.set_attribute('sample_method', SAMPLE_METHOD)
  a.algorithm.set_attribute('number_of_samples', NUMBER_OF_SAMPLES)

  # save files
  a.save formulation_file
  a.save_zip zip_file

end


def create_model_workflow_gem(path)
  # NICK: make a single model. Save the log messages.
  # - Remove system call to zip
  # - Add method to just create the open studio model
  # - Put each zip/json file in its own directory (DG)
  # - Allow for no data point file (set to default/static values)
  # - Paths to energyplus and openstudio on windows

  k = OpenStudio::Workflow.run_energyplus 'Local', path

  options = {
      problem_filename: 'analysis_1.json',
      datapoint_filename: 'datapoint_1.json',
      analysis_root_path: 'spec/files/example_models',
      use_monthly_reports: true
  }
  k = OpenStudio::Workflow.load 'Local', path, options

end

# this will create model (eventually IDF and sim run) from script in projects directory
# todo - this will eventually be replaced with method to make models from json files in the analysis directory
def create_model(value_set,seed_model,save_string)

  measures = populate_workflow(value_set,seed_model)

  # todo - accommodate measures with string/path arguments it would be better for this section to run on the contents of the zip file. Then paths would match what happens on the server.

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
    puts "Couldn't open #{seed_model}, creating a new empty model"
    model = OpenStudio::Model::Model.new
  end

  model_measures = []

  # add model measures to analysis
  measures.each do |m|

    # load the measure
    require_relative (Dir.pwd + "/" + m[:path] + "/measure.rb")

    # load the measure.json file
    path_to_measure_json =  (Dir.pwd + "/" + m[:path] + "/measure.json")
    measure_json = JSON.parse(File.read(path_to_measure_json))
    measure_class = measure_json["classname"]

    # get name and description from measure.json if it doesn't already exist
    if not m[:name]
      m[:name] = measure_json["name"]
    end
    if not m[:description]
      m[:description] = measure_json["description"]
    end

    # make empty array for arguments and variables if not passed in
    if not m[:arguments]
      m[:arguments] = []
    end
    if not m[:variables]
      m[:variables] = []
    end

    # create an instance of the measure
    measure = eval(measure_class).new

    # skip from this loop if it is an E+ or Reporting measure
    if not measure.is_a?(OpenStudio::Ruleset::ModelUserScript)
      puts "Skipping #{measure.name}. It isn't a model measure."
      next
    else
      model_measures << m
    end

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # get argument values
    args_hash = {}
    m[:arguments].each do |a|
      if a[:value].is_a?(Hash)
        args_hash[a[:name]] = a[:value][:static_value]
      else
        args_hash[a[:name]] = a[:value]
      end
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
  output_file_path = OpenStudio::Path.new("analysis_local/#{save_string}.osm")
  puts "Saving #{output_file_path}"
  model.save(output_file_path,true)

  # forward translate to IDF
  puts "Forward translating #{output_file_path} to an IDF model"
  # forward translate OSM file to IDF file
  ft = OpenStudio::EnergyPlus::ForwardTranslator.new
  workspace = ft.translateModel(model)

  energy_plus_measures = []

  # add energy plus measures to analysis
  measures.each do |m|

    # stop here if measure already identified as model measure
    if model_measures.include? m
      next
    end

    # load the measure
    require_relative (Dir.pwd + "/" + m[:path] + "/measure.rb")

    # get the measure class name from the JSON file
    path_to_measure_json =  (Dir.pwd + "/" + m[:path] + "/measure.json")
    temp = File.read(path_to_measure_json)
    measure_json = JSON.parse(temp)
    measure_class = measure_json["classname"]

    # create an instance of the measure
    measure = eval(measure_class).new

    # skip from this loop if it is an E+ or Reporting measure
    if not measure.is_a?(OpenStudio::Ruleset::WorkspaceUserScript)
      puts "Skipping #{measure.name}. It isn't an EnergyPlus measure."
      next
    else
      energy_plus_measures << m
    end

    # get arguments
    arguments = measure.arguments(workspace)
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
    measure.run(workspace, runner, argument_map)
    result = runner.result
    show_output(result)

  end

  # save path
  output_file_path = OpenStudio::Path.new("analysis_local/#{save_string}.idf")
  puts "Saving #{output_file_path}"
  workspace.save(output_file_path,true)

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

namespace :workflow do

  # set constants
  server_dns = 'nrel24a'
  case server_dns
    when 'vagrant'
      HOSTNAME = 'http://localhost:8080'
    when 'nrel24a'
      HOSTNAME = 'http://bball-130553.nrel.gov:8080'
    when 'nrel24b'
      HOSTNAME = 'http://bball-130590.nrel.gov:8080'
    else
      # can use this to pass in other server such as aws
      HOSTNAME = server_dns
  end
  ANALYSIS_TYPE = 'lhs' # valid options [batch_run,lhs,optim,regenoud,nsga_nrel,preflight,sequential_search,single_run]
  SAMPLE_METHOD = 'all_variables' # valid options [individual_variables,all_variables]
  NUMBER_OF_SAMPLES = 100 # valid options are any positive integer

  desc 'make analysis jsons from specified workflow script'
  task :make_jsons do
    script = get_scripts
    workflow_create_jsons()
  end

  desc 'make analysis models from specified workflow script'
  task :make_models do
    script = get_scripts
    workflow_create_models()
  end

  desc 'queue the jsons already in the analysis directory'
  task :queue_populate do

    analysis_jsons = Dir["analysis/**/*.json"]
    puts "found #{analysis_jsons.size} jsons in #{Dir.pwd}"

    # loop through jsons found in the directory
    analysis_jsons.each do |json|
      save_string = json.downcase.gsub('.json','') # remove the extension
      formulation_file = "#{save_string}.json"
      zip_file = "#{save_string}.zip"
      if File.exist?(formulation_file) && File.exist?(zip_file)
        puts "Running #{save_string}"
        api = OpenStudio::Analysis::ServerApi.new( { hostname: HOSTNAME } )
        api.queue_single_run(formulation_file, zip_file, ANALYSIS_TYPE)
      else
        puts "Could not file JSON or ZIP for #{save_string}"
      end
    end
  end

  desc 'start the run queue'
  task :queue_start do
    api = OpenStudio::Analysis::ServerApi.new( { hostname: HOSTNAME } )
    api.run_batch_run_across_analyses(nil, nil, ANALYSIS_TYPE)
  end

  desc 'run pre made analysis json'
  task :run_jsons do

    analysis_jsons = Dir["analysis/**/*.json"]
    puts "found #{analysis_jsons.size} jsons in #{Dir.pwd}"

    # loop through jsons found in the directory
    analysis_jsons.each do |json|
      save_string = json.downcase.gsub('.json','') # remove the extension
      formulation_file = "#{save_string}.json"
      zip_file = "#{save_string}.zip"
      if File.exist?(formulation_file) && File.exist?(zip_file)
        puts "Running #{save_string}"
        api = OpenStudio::Analysis::ServerApi.new( { hostname: HOSTNAME } )
        j = JSON.parse(File.read(json), symbolize_names: true)
        analysis_type = j[:analysis][:problem][:analysis_type]
        api.run(json, zip_file, analysis_type.to_s)
      else
        puts "Could not file JSON or ZIP for #{save_string}"
      end
    end

  end

end