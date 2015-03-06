# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

#load OpenStudio measure libraries
require "#{File.dirname(__FILE__)}/resources/os_lib_helper_methods"
require "#{File.dirname(__FILE__)}/resources/os_lib_geometry"

# start the measure
class ImportGeometryFromOsm < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "ImportGeometryFromOsm"
  end

  # human readable description
  def description
    return "I think this will just import raw geometry, but need to consider if it should have space types, constructions, or anything else"
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make an argument for the electric tariff
    choices = OpenStudio::StringVector.new
    choices << "SchoolGeometryOnly"
    structure = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('structure', choices, true)
    structure.setDisplayName("Choose Envelope to Import.")
    structure.setDefaultValue("SchoolGeometryOnly")
    args << structure

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    structure = runner.getStringArgumentValue("structure",user_arguments)

    #load the idf file containing the electric tariff
    structure_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/resources/#{structure}.osm")
    structure_file = OpenStudio::IdfFile::load(structure_path)

    if structure_file.empty?
      runner.registerError("Unable to find the file #{structure}.osm")
      return false
    else
      structure_file = structure_file.get
    end

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getSpaces.size} spaces.")

    # import geometry
    # todo - I want to replace this with a version that adds spaces without removing the rest of the model.
    OsLib_Geometry.add_geometry(model, structure_path, true) # this deletes everything else in the model.

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getSpaces.size} spaces.")

    return true

  end
  
end

# register the measure to be used by the application
ImportGeometryFromOsm.new.registerWithApplication
