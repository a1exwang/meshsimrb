require_relative '../lib/fast_4d_matrix/fast_4d_matrix'
require 'rspec'

RSpec.describe Fast4DMatrix do
  it 'can create Vec3 objects' do
    vec3 = Fast4DMatrix::Vec3.from_a(1.0, 2.0, 3.0)
    expect(vec3.to_a).to eq([1.0, 2.0, 3.0])
  end

  it 'can get middle point' do
    vec1 = Fast4DMatrix::Vec3.from_a(1.0, 2.0, 3.0)
    vec2 = Fast4DMatrix::Vec3.from_a(4.0, 5.0, 6.0)
    expect(vec1.mid(vec2).to_a).to eq([2.5, 3.5, 4.5])
  end

  it 'can create zero matrix' do
    zero = Fast4DMatrix::Matrix4Sym.zero
    expect(zero.to_a).to eq(Array.new(4) { Array.new(4, 0) })
  end

  it 'can create matrix with vec4' do
    m = Fast4DMatrix::Matrix4Sym.from_vec4(1.0, 1.0, 1.0, 1.0)
    expect(m.to_a).to eq(Array.new(4) { Array.new(4, 1) })
  end

  it 'can create matrix from face' do
    vec1 = Fast4DMatrix::Vec3.from_a(0.0, 1.0, 0.0)
    vec2 = Fast4DMatrix::Vec3.from_a(0.0, 2.0, 0.0)
    vec3 = Fast4DMatrix::Vec3.from_a(0.0, 2.0, 3.0)
    m = Fast4DMatrix::Matrix4Sym.from_face(vec1, vec2, vec3)
    result = Array.new(4) { Array.new(4, 0) }
    result[0][0] = 1
    expect(m.to_a).to eq(result)
  end

  it 'can calculate delta with face and vector' do
    m = Fast4DMatrix::Matrix4Sym.from_vec4(1.0, 1.0, 1.0, 1.0)
    vec = Fast4DMatrix::Vec3.from_a(1.0, 1.0, 1.0)
    expect(m.delta(vec)).to eq(16)
  end

  it 'can calculate delta with random face and vector' do
    vs = Array.new(3) { Array.new(3) { rand } }
    vec = Array.new(3) { rand }

    m = Fast4DMatrix::Matrix4Sym.from_face(Fast4DMatrix::Vec3.from_a(*vs[0]),
                                           Fast4DMatrix::Vec3.from_a(*vs[1]),
                                           Fast4DMatrix::Vec3.from_a(*vs[2]))
    vec1 = Fast4DMatrix::Vec3.from_a(*vec)

    def calculate_kp(v1, v2, v3)
      vec1, vec2, vec3 = *[v1, v2, v3].map { |x| Vector[*x] }
      n = (vec1 - vec2).cross(vec1 - vec3)
      # (m.dot m.transpose).to_f
      raise "#{[vec1, vec2, vec3]} cannot make a face" if n.r == 0
      nn = n.normalize
      # p = Matrix[[nn[0], nn[1], nn[2], -nn.dot(vec1)]]
      # p.t * p
      p = Matrix[nn.to_a + [-nn.dot(vec1)]]
      p.t * p
    end

    dst_v = Matrix[*vec.to_a.map { |x| [x] }, [1]]
    correct = (dst_v.t * calculate_kp(*vs) * dst_v).to_a.first.first
    expect(m.delta(vec1).round(5)).to eq(correct.round(5))
  end

  it 'can add matrix' do
    m1 = Fast4DMatrix::Matrix4Sym.from_vec4(1.0, 1.0, 1.0, 1.0)
    m2 = Fast4DMatrix::Matrix4Sym.from_vec4(2.0, 2.0, 2.0, 2.0)
    m1.add!(m2)
    expect(m1.to_a).to eq(Array.new(4) { Array.new(4, 5) })
  end

  #it 'can check verteces on the same line' do
  #  v1 = Fast4DMatrix::Vec3.from_a(0.0, 0.0, 0.0)
  #  v2 = Fast4DMatrix::Vec3.from_a(1.0, 0.0, 0.0)
  #  v3 = Fast4DMatrix::Vec3.from_a(2.0, 0.0, 0.0)

  #  expect(v1.line?(v2, v3)).to be_truthy
  #  expect(v2.line?(v3, v1)).to be_truthy
  #  expect(v3.line?(v2, v1)).to be_truthy
  #end

  it 'can check verteces not on the same line' do
    v1 = Fast4DMatrix::Vec3.from_a(0.0, 2.0, 0.0)
    v2 = Fast4DMatrix::Vec3.from_a(1.0, 0.0, 0.0)
    v3 = Fast4DMatrix::Vec3.from_a(2.0, 0.0, 0.0)

    expect(v1.line?(v2, v3)).to be_falsey
    #expect(v2.line?(v3, v1)).to be_falsey
    #expect(v3.line?(v2, v1)).to be_falsey
  end

  it 'can solve linear equ' do
    mat1 = Fast4DMatrix::Matrix4Sym.from_vec4(1.0, 1.0, 1.0, 1.0)
    mat2 = Fast4DMatrix::Matrix4Sym.from_vec4(2.0, 4.0, 8.0, 1.0)
    mat3 = Fast4DMatrix::Matrix4Sym.from_vec4(3.0, 2.0, 1.0, 1.0)
    mat1.add!(mat2)
    mat1.add!(mat3)
    expect(mat1.get_best_vertex.to_a).to eq([3.5, -7, 2.5])
  end

end
