require_relative '../lib/fast_4d_matrix/fast_4d_matrix'
require 'rspec'

RSpec.describe Fast4DMatrix do
  it 'can create Vec3 objects' do
    vec3 = Fast4DMatrix::Vec3.new(1.0, 2.0, 3.0)
    expect(vec3.to_a).to eq([1.0, 2.0, 3.0])
  end

  it 'can create zero matrix' do
    zero = Fast4DMatrix::Matrix4Sym.zero
    expect(zero.to_a).to eq([[0.0] * 4] * 4)
  end

  it 'can create matrix with vec4' do
    m = Fast4DMatrix::Matrix4Sym.from_vec4(1.0, 1.0, 1.0, 1.0)
    expect(m.to_a).to eq([[1] * 4] * 4)
  end

  it 'can create matrix from face' do
    vec1 = Fast4DMatrix::Vec3.new(0.0, 1.0, 0.0)
    vec2 = Fast4DMatrix::Vec3.new(0.0, 2.0, 0.0)
    vec3 = Fast4DMatrix::Vec3.new(0.0, 2.0, 3.0)
    m = Fast4DMatrix::Matrix4Sym.from_face(vec1, vec2, vec3);
    result = [[0] * 4] * 4
    result[0][0] = 1
    expect(m.to_a).to eq(result)
  end

end