require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'

class ImportGeometryFromOsmTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_good_argument_values
    # create an instance of the measure
    measure = ImportGeometryFromOsm.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/test_input.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get


    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # set argument values to good values
    structure = arguments[0].clone
    assert(structure.setValue("SchoolGeometryOnly"))
    argument_map["structure"] = structure

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    assert_equal("Success", result.value.valueName)
    show_output(result)

    # save the model
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/test.osm")
    model.save(output_file_path,true)

  end

end
