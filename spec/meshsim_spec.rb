require_relative '../meshsim'
require 'rspec'

RSpec.describe MeshSim do
  it 'can simplify cube' do
    root = File.join(File.dirname(__FILE__), '..')

    expect do
      MeshSim.meshsim(File.join(root, 'test_data', 'cube.obj'),
                      File.join(root, 'out', 'cube.test.0.05.obj'),
                      0.05,
                      MeshSim::V_SILENT
      )
    end.to_not raise_error
  end

  # it 'can simplify dinosaur' do
  #   root = File.join(File.dirname(__FILE__), '..')
  #
  #   expect do
  #     MeshSim.meshsim(File.join(root, 'test_data', 'dinosaur.2k.obj'),
  #                     File.join(root, 'out', 'dinosaur.2k.test.0.05.obj'),
  #                     0.05,
  #                     MeshSim::V_SILENT
  #     )
  #   end.to_not raise_error
  # end

end