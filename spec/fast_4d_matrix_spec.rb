require_relative '../lib/fast_4d_matrix/fast_4d_matrix'
require 'rspec'

RSpec.describe Fast4DMatrix do
  it 'can create Vec3 objects' do
    vec3 = Fast4DMatrix::Vec3.new(1.0, 2.0, 3.0)
    expect(vec3.to_a).to eq([1.0, 2.0, 3.0])
  end

  it 'can create zero matrix' do
    zero = Fast4DMatrix::Matrix4Sym.zero
    expect(zero.to_a).to eq(Array.new(4) { Array.new(4, 0) })
  end

  it 'can create matrix with vec4' do
    m = Fast4DMatrix::Matrix4Sym.from_vec4(1.0, 1.0, 1.0, 1.0)
    expect(m.to_a).to eq(Array.new(4) { Array.new(4, 1) })
  end

  it 'can raise error with an invalid face' do
    vec1 = Fast4DMatrix::Vec3.new(0.0, 1.0, 0.0)
    vec2 = Fast4DMatrix::Vec3.new(0.0, 2.0, 0.0)
    vec3 = Fast4DMatrix::Vec3.new(0.0, 3.0, 0.0)
    expect do
      Fast4DMatrix::Matrix4Sym.from_face(vec1, vec2, vec3)
    end.to raise_error(StandardError)
  end

  it 'can create matrix from face' do
    vec1 = Fast4DMatrix::Vec3.new(0.0, 1.0, 0.0)
    vec2 = Fast4DMatrix::Vec3.new(0.0, 2.0, 0.0)
    vec3 = Fast4DMatrix::Vec3.new(0.0, 2.0, 3.0)
    m = Fast4DMatrix::Matrix4Sym.from_face(vec1, vec2, vec3)
    result = Array.new(4) { Array.new(4, 0) }
    result[0][0] = result[0][3] = result[3][0] = result[3][3] = 1
    expect(m.to_a).to eq(result)
  end

  it 'can calculate delta with face and vector' do
    m = Fast4DMatrix::Matrix4Sym.from_vec4(1.0, 1.0, 1.0, 1.0)
    vec = Fast4DMatrix::Vec3.new(1.0, 1.0, 1.0)
    expect(m.delta(vec)).to eq(16)
  end

  it 'can add matrix' do
    m1 = Fast4DMatrix::Matrix4Sym.from_vec4(1.0, 1.0, 1.0, 1.0)
    m2 = Fast4DMatrix::Matrix4Sym.from_vec4(2.0, 2.0, 2.0, 2.0)
    m1.add!(m2)
    expect(m1.to_a).to eq(Array.new(4) { Array.new(4, 5) })
  end

end