require_relative '../lib/fast_4d_matrix'
require 'rspec'

RSpec.describe Fast4DMatrix do
  it 'can create new objects' do
    obj = Fast4DMatrix.new
    expect(obj.get_value).to eq(10)
  end
end