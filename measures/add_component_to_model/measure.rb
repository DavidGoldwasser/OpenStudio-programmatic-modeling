# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class AddComponentToModel < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "AddComponentToModel"
  end

  # human readable description
  def description
    return "This is a proof of concept to pull a component into the model from the resources directory of the measure. Not sure if it will just pull the component in, or if wl attempt to hook it up."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Once I figure out what kind of component I'll rename and update the description, will probably "
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make an argument for the electric tariff
    choices = OpenStudio::StringVector.new
    choices << "Interior Wall"
    construction = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('construction', choices, true)
    construction.setDisplayName("Choose Construction Component to Import.")
    construction.setDefaultValue("Interior Wall")
    args << construction

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
    construction = runner.getStringArgumentValue("construction",user_arguments)

    #load the idf file containing the electric tariff
    construction_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/resources/#{construction}.osc")
    construction_file = OpenStudio::IdfFile::load(construction_path)

    if construction_file.empty?
      runner.registerError("Unable to find the file #{construction}.osc")
      return false
    else
      construction_file = construction_file.get
    end

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getConstructions.size} constructions.")

    vt = OpenStudio::OSVersion::VersionTranslator.new
    constructionComponent = vt.loadComponent(OpenStudio::Path.new(construction_path))
    if constructionComponent.empty?
      runner.registerError("translateSurfaceConstruction: Cannot load construction component '#{construction_file}'")
      return false
    else
      object = constructionComponent.get.primaryObject
      if object.to_Construction.empty?
        runner.registerError("translateSurfaceConstruction: Construction component '#{construction_file}' does not include a construction object")
        return false
      else
        componentData = model.insertComponent(constructionComponent.get)
        if componentData.empty?
          runner.registerError("translateSurfaceConstruction: Failed to insert construction component '#{construction_file}' into model")
          return false
        else
          componentData.get.primaryComponentObject.to_Construction.get
        end
      end
    end

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getConstructions.size} constructions.")

    return true

  end
  
end

# register the measure to be used by the application
AddComponentToModel.new.registerWithApplication
