module Fast4DMatrix
  class Vec3
    # method stub
    def self.from_a(a, b, c); raise NotImplementedError; end
    def to_a; raise NotImplementedError; end
  end
  class Matrix4Sym
    # method stub
    def self.from_vec4(a, b, c, d); raise NotImplementedError; end
    def self.from_face(v1, v2, v3); raise NotImplementedError; end
    def self.zero; raise NotImplementedError; end
    def add!(other); raise NotImplementedError; end
    def delta(vector); raise NotImplementedError; end
    def to_a; raise NotImplementedError; end
  end
end

require_relative '../fast_4d_matrix'
