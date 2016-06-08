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

  def modify_face(fid, src, dst)
    raise "vertex #{src} is not on face #{fid}" unless @vertices[src][:faces].include?(fid)
    @vertices[src][:faces].delete fid
    raise "vertex #{dst} is on face #{fid}" if @vertices[dst][:faces].include?(fid)
    @vertices[dst][:faces] << fid
  end

  def modify_line(v1, src, dst)
    raise "vertex #{src} is not associated with #{v1}" unless @vertices[src][:associated_vertices].include?(v1)
    @vertices[v1][:associated_vertices].delete src
    raise ArgumentError, "vertex #{dst} is associated with #{v1}" if @vertices[dst][:associated_vertices].include?(v1)
    @vertices[v1][:associated_vertices] << dst

    @vertices[dst][:associated_vertices] << v1

    raise "vertex #{v1} is not associated with #{src}" unless @vertices[src][:associated_vertices].include?(v1)
    @vertices[src][:associated_vertices].delete v1
  end

  def to_obj
    str = ''
    v_index = 0
    v_mappings = {}
    total_size = @vertices.size
    i = 0
    @vertices.each do |id, v|
      v_mappings[id] = v_index
      v_index += 1
      str += "v #{v[:vector].to_a.map { |x| x.to_s }.join(' ')}\n"
      puts "formatting vertices #{(100.0 * i / total_size).round(2)}%..." if i == (0.01*total_size).round && VERBOSE >= V_NORMAL
      i += 1
    end
    puts 'formatting vertices done' if VERBOSE >= V_NORMAL
    str += "\n"
    [str, v_mappings]
  end

  def dump_to_s
    str = "vertices\n"
    @vertices.each do |id, v|
      str += "vertex #{id}, faces: #{v[:faces].sort.join(' ')}\n\tassociated: #{v[:associated_vertices].sort.join(' ')}\n"
    end
    str
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
    rescue ArgumentError => e
      puts e if VERBOSE > V_NORMAL
    end
    begin
      add_line(v1, v3)
    rescue ArgumentError => e
      puts e if VERBOSE > V_NORMAL
    end
    begin
      add_line(v3, v2)
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
      v1, v2 = v2, v1 if v1 > v2
      ret = @lines[v1].delete v2
      @lines.delete v1 if @lines[v1].size == 0
      ret
    else
      raise "trying to delete non-existing line #{v1}-#{v2}"
    end
  end

  def modify_line(v1, src, dst)
    delete_line(v1, src)
    begin
      add_line(v1, dst)
    rescue ArgumentError => e
      puts e if VERBOSE > V_NORMAL
    end
  end

  def first
    @lines.first.last.first.last[:vertices]
  end

  def dump_to_s
    str = "lines\n"
    each_line do |v1, v2, l|
      str += "\t#{v1}-#{v2}\n"
    end
    str
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

  def modify_face(id, src, dst)
    raise "trying to modify non-existing face #{id}" unless @faces[id]
    raise "trying to remove non-existing vertex #{src} on face #{id}" unless @faces[id][:vertices].include?(src)
    @faces[id][:vertices].delete src
    raise "trying to add existing vertex #{src} on face #{id}" if @faces[id][:vertices].include?(dst)
    @faces[id][:vertices] << dst
  end

  def to_obj(v_mappings)
    str = ''
    total_size = @faces.size
    i = 0
    @faces.each do |_id, face|
      v1, v2, v3 = face[:vertices].to_a
      puts "f #{v1} #{v2} #{v3}" if VERBOSE > V_NORMAL
      str += "f #{face[:vertices].to_a.map { |x| v_mappings[x] ? v_mappings[x] + 1 : (raise "no mapping #{x}") }.join(' ')}\n"
      puts "formatting faces #{(100.0 * i / total_size).round(2)}%" if i == (total_size * 0.01).round && VERBOSE >= V_NORMAL
      i += 1
    end
    puts 'formatting faces done' if VERBOSE >= V_NORMAL
    str
  end
  def dump_to_s
    str = "faces\n"
    @faces.each do |id, f|
      str += "\tf #{id}, vertices: #{f[:vertices].sort.join(' ')}\n"
    end
    str
  end
end

class ObjectManager
  def initialize(file_path)
    @vertices = Vertices.new
    @lines = Lines.new
    @faces = Faces.new
    # 初始化所有点, 面
    # 点: { vector: Vector[x, y, z], faces: [face_id, ..], lines: [line_id, ..] }
    # 面: { vertices: [v_id, ...], kp: Matrix[] }
    # 线: { vertices: [v_id, ...], delta: 1.0 }
    v_id = 0
    File.read(file_path).split("\n").each do |line|
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

  def merge_vertex(src, dst)
    puts "\nmerging #{src} -> #{dst}" if VERBOSE >= V_NORMAL
    # modify and delete faces
    faces_that_has_changed = []
    f1 = @vertices.get_associated_face_ids(src)
    f2 = @vertices.get_associated_face_ids(dst)
    faces_to_delete = f1 & f2
    faces_to_modify = f1 - f2
    faces_that_has_changed = faces_to_modify
    # after here, f1, f2 are invalid
    faces_to_delete.each do |fid|
      vs = @faces.get_vertices(fid)
      @faces.delete_face(fid)
      @vertices.delete_face(vs, fid)
    end
    faces_to_modify.each do |fid|
      @faces.modify_face(fid, src, dst)
      @vertices.modify_face(fid, src, dst)
    end

    # modify and delete lines
    lines_that_has_changed = []
    lines_to_touch = @vertices.get_associated_vertex_ids(src)
    raise "#{dst} is not associated with #{src}" unless lines_to_touch.include?(dst)
    lines_to_modify = lines_to_touch - [dst]
    lines_to_modify.each do |v2|
      # the line is src-v2
      @lines.modify_line(v2, src, dst)
      begin
        @vertices.modify_line(v2, src, dst)
      rescue ArgumentError => e
        puts e if VERBOSE > V_NORMAL
      end
      lines_that_has_changed << [v2, dst]
    end

    @lines.delete_line(src, dst)
    @vertices.delete_line(src, dst)

    @vertices.delete(src)
  end

  def get_a_line
    @lines.first
  end

  def write_to_file(file_path)
    vertices_str, v_mappings = @vertices.to_obj
    faces_str = @faces.to_obj(v_mappings)
    File.write(file_path, vertices_str + faces_str)
  end

  def dump_print
    puts @vertices.dump_to_s
    puts @lines.dump_to_s
    puts @faces.dump_to_s
  end
end

obj = ObjectManager.new('test_data/cube.obj')

obj.dump_print

5.times do
  v1, v2 = obj.get_a_line
  obj.merge_vertex(v1, v2)
  obj.dump_print
end

obj.write_to_file('a.obj')