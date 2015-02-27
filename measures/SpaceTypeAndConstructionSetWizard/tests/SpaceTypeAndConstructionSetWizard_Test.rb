require 'openstudio'

require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'minitest/autorun'

class SpaceTypeAndConstructionSetWizard_Test < MiniTest::Unit::TestCase

  
  def test_SpaceTypeAndConstructionSetWizard
     
    # create an instance of the measure
    measure = SpaceTypeAndConstructionSetWizard.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EmptySeedModel.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(6, arguments.size)
    count = -1
    assert_equal("buildingType", arguments[count += 1].name)
    assert_equal("template", arguments[count += 1].name)
    assert_equal("climateZone", arguments[count += 1].name)
    assert_equal("createSpaceTypes", arguments[count += 1].name)
    assert_equal("createConstructionSet", arguments[count += 1].name)
    assert_equal("setBuildingDefaults", arguments[count += 1].name)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1

    buildingType = arguments[count += 1].clone
    #assert(buildingType.setValue("MidriseApartment"))
    assert(buildingType.setValue("Retail"))
    argument_map["buildingType"] = buildingType

    template = arguments[count += 1].clone
    #assert(template.setValue("DOE Ref 2004"))
    assert(template.setValue("90.1-2007"))
    argument_map["template"] = template

    climateZone = arguments[count += 1].clone
    assert(climateZone.setValue("ASHRAE 169-2006-5A"))
    argument_map["climateZone"] = climateZone

    createSpaceTypes = arguments[count += 1].clone
    assert(createSpaceTypes.setValue(true))
    argument_map["createSpaceTypes"] = createSpaceTypes

    createConstructionSet = arguments[count += 1].clone
    assert(createConstructionSet.setValue(true))
    argument_map["createConstructionSet"] = createConstructionSet

    setBuildingDefaults = arguments[count += 1].clone
    assert(setBuildingDefaults.setValue(true))
    argument_map["setBuildingDefaults"] = setBuildingDefaults

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 1)
    #assert(result.info.size == 2)

    # save the model in an output directory
    output_dir = File.expand_path('output', File.dirname(__FILE__))
    FileUtils.mkdir output_dir unless Dir.exist? output_dir
    model.save("#{output_dir}/test.osm", true)
  end  

end
