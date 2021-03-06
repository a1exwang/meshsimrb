require_relative '../meshsim'

require 'rspec'

RSpec.describe  do
  before :all do
    MeshSimStub = Module.new
    vertices = Array.new(10) { Array.new(3) { rand } }
    MeshSimStub.module_eval do
      define_method :get_vec do |id|
        vertices[id]
      end
      define_method :get_associated_face_vertices do |src_id|
        [[src_id + 1, src_id + 2]]
      end
    end

    class Fast
      include MeshSim::MatrixMathMixinFast
      include MeshSimStub
    end
    class Slow
      include MeshSim::MatrixMathMixinSlow
      include MeshSimStub
    end
  end

  it 'can calculate_kp' do
    fast = Fast.new.calculate_kp(0, 1, 2).to_a
    slow = Slow.new.calculate_kp(0, 1, 2).to_a

    expect(fast.flatten.map { |x| x.round(2) }).to eq(slow.flatten.map { |x| x.round(2) })
  end

  # it 'can get delta' do
  #   fast_faces = Object.new
  #   def fast_faces.get_kp (v1, v2, v3)
  #     Fast.new.calculate_kp(v1, v2, v3)
  #   end
  #
  #   slow_faces = Object.new
  #   def slow_faces.get_kp(v1, v2, v3)
  #     Slow.new.calculate_kp(v1, v2, v3)
  #   end
  #
  #   fast = Fast.new
  #   slow = Slow.new
  #
  #   delta1 = fast.delta(fast_faces, 0, 9)
  #   delta2 = slow.delta(slow_faces, 0, 9)
  #   expect(delta1.round(5)).to eq(delta2.round(5))
  # end

  it 'slow can get best vertex' do
    slow = Slow.new
    a, b, c = rand, rand, rand
    kp = Matrix[
      [1, 0, 0, a],
      [0, 1, 0, b],
      [0, 0, 1, c],
      [0, 0, 0, 1]
    ]
    v1 = Vector[2, 0, 0]
    v2 = Vector[0, 2, 0]

    v = slow.get_best_vertex(kp, v1, v2)
    expect(v.to_a).to eq([-a, -b, -c])

    kp = Matrix[
        [0, 0, 0, a],
        [0, 1, 0, b],
        [0, 0, 1, c],
        [0, 0, 0, 1]
    ]
    v = slow.get_best_vertex(kp, v1, v2)
    expect(v.to_a).to eq([1, 1, 0])
  end

end
