require 'matrix'

V_DBG = 10
V_VERBOSE = 5
V_NORMAL = 1
V_SILENT = 0

VERBOSE = V_NORMAL

class Vertices
  def initialize
    @vertices = {}
  end

  def add_vertex(id, vector)
    @vertices[id] = { vector: vector, faces: [], associated_vertices: [] }
  end

  def attach_to_face(face_id, v1, v2, v3)
    raise "vertex #{v1} already on face #{face_id}" if @vertices[v1][:faces].include?(face_id)
    @vertices[v1][:faces] << face_id
    @vertices[v1][:associated_vertices] << v2 unless @vertices[v1][:associated_vertices].include?(v2)
    @vertices[v1][:associated_vertices] << v3 unless @vertices[v1][:associated_vertices].include?(v3)

    raise "vertex #{v1} already on face #{face_id}" if @vertices[v2][:faces].include?(face_id)
    @vertices[v2][:faces] << face_id
    @vertices[v2][:associated_vertices] << v1 unless @vertices[v2][:associated_vertices].include?(v1)
    @vertices[v2][:associated_vertices] << v3 unless @vertices[v2][:associated_vertices].include?(v3)

    raise "vertex #{v1} already on face #{face_id}" if @vertices[v3][:faces].include?(face_id)
    @vertices[v3][:faces] << face_id
    @vertices[v3][:associated_vertices] << v2 unless @vertices[v3][:associated_vertices].include?(v2)
    @vertices[v3][:associated_vertices] << v1 unless @vertices[v3][:associated_vertices].include?(v1)
  end

  def get(id)
    raise "no such vertex #{id}" unless @vertices[id]
    @vertices[id][:vector]
  end

  def delete(id)
    raise "no such vertex #{id}" unless @vertices[id]
    @vertices.delete id
  end

  def delete_face(vertices_ids, face_id)
    vertices_ids.each do |vertex_id|
      faces = @vertices[vertex_id][:faces]
      if faces.include?(face_id)
        faces.delete(face_id)
      else
        raise "vertex #{vertex_id} is not on face #{face_id}"
      end
    end
  end

  def delete_line(v1, v2)
    raise "data corruption detected, #{v2} is not in #{v1}'s associated list" unless @vertices[v1][:associated_vertices].include?(v2)
    raise "data corruption detected, #{v1} is not in #{v2}'s associated list" unless @vertices[v2][:associated_vertices].include?(v1)

    @vertices[v1][:associated_vertices].delete v2
    @vertices[v2][:associated_vertices].delete v1
  end

  def get_associated_face_ids(id)
    raise "no such vertex #{id}" unless @vertices[id]
    @vertices[id][:faces]
  end

  def get_associated_vertex_ids(id)
    raise "no such vertex #{id}" unless @vertices[id]
    @vertices[id][:associated_vertices]
  end
end

class Lines
  def initialize
    @lines = {}
  end

  def get_delta(v1, v2)
    get(v1, v2)[:delta]
  end

  def add_lines_by_face(v1, v2, v3)
    begin
      add_line(v1, v2)
      add_line(v1, v3)
      add_line(v2, v3)
    rescue ArgumentError => e
      puts e if VERBOSE > V_NORMAL
    end
  end

  def add_line(v1, v2)
    raise "two same vertices cannot make a line #{v1}" if v1 == v2
    v1, v2 = v2, v1 if v1 > v2
    @lines[v1] = {} unless @lines[v1]
    raise ArgumentError, "line #{v1}-#{v2} already exist" if @lines[v1][v2]
    @lines[v1][v2] = { vertices: [v1, v2] }
  end

  def each_line(&block)
    raise 'no block given' unless block
    @lines.each do |v1, v|
      v.each do |v2, line|
        block.call(v1, v2, line)
      end
    end
  end

  def delete_line(v1, v2)
    if get(v1, v2)
      @lines[v1].delete v2
      @lines.delete v1 if @lines[v1].size == 0
    else
      raise "trying to delete non-existing line #{v1}-#{v2}"
    end
  end

  def first
    @lines.first.last.first.last[:vertices]
  end

  private
  def get(v1, v2)
    v1, v2 = v2, v1 if v1 > v2
    ret = @lines[v1][v2]
    raise "line #{v1}-#{v2} does not exist" unless ret
    ret
  end
end

class Faces
  def initialize
    @faces = {}
    @current_index = 0
  end

  def add_face(v1, v2, v3)
    @faces[@current_index] = { vertices: [v1, v2, v3] }
    @current_index += 1
    @current_index - 1
  end

  def delete_face(id)
    raise "trying to delete non-existing face #{id}" unless @faces[id]
    @faces.delete id
  end

  def get_vertices(id)
    raise "trying to get non-existing face #{id}" unless @faces[id]
    @faces[id][:vertices]
  end
end

class ObjectManager
  def initialize(filename)
    @vertices = Vertices.new
    @lines = Lines.new
    @faces = Faces.new
    # 初始化所有点, 面
    # 点: { vector: Vector[x, y, z], faces: [face_id, ..], lines: [line_id, ..] }
    # 面: { vertices: [v_id, ...], kp: Matrix[] }
    # 线: { vertices: [v_id, ...], delta: 1.0 }
    v_id = 0
    File.read(filename).split("\n").each do |line|
      type, *rest = line.split(' ')
      case type
        when 'v'
          @vertices.add_vertex(v_id, Vector[*(rest.map { |x| x.to_f })])
          v_id += 1
        when 'f'
          vs = rest.map { |x| x.to_i - 1 }
          @lines.add_lines_by_face(*vs)
          face_id = @faces.add_face(*vs)
          @vertices.attach_to_face(face_id, *vs)
      end
    end
  end
end

obj = ObjectManager.new('test_data/dinosaur.2k.obj')