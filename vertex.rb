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
    @vertices[v1][:faces] << [v2, v3].sort
    @vertices[v1][:associated_vertices] << v2 unless @vertices[v1][:associated_vertices].include?(v2)
    @vertices[v1][:associated_vertices] << v3 unless @vertices[v1][:associated_vertices].include?(v3)

    raise "vertex #{v1} already on face #{face_id}" if @vertices[v2][:faces].include?(face_id)
    @vertices[v2][:faces] << [v1, v3].sort
    @vertices[v2][:associated_vertices] << v1 unless @vertices[v2][:associated_vertices].include?(v1)
    @vertices[v2][:associated_vertices] << v3 unless @vertices[v2][:associated_vertices].include?(v3)

    raise "vertex #{v1} already on face #{face_id}" if @vertices[v3][:faces].include?(face_id)
    @vertices[v3][:faces] << [v1, v2].sort
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

  def delete_face(v1, v2, v3)
    raise "vertex #{v1} is not on face #{[v2, v3]}" unless @vertices[v1][:faces].include? [v2, v3].sort
    @vertices[v1][:faces].delete [v2, v3].sort
    raise "vertex #{v2} is not on face #{[v1, v3]}" unless @vertices[v2][:faces].include? [v1, v3].sort
    @vertices[v2][:faces].delete [v1, v3].sort
    raise "vertex #{v3} is not on face #{[v2, v1]}" unless @vertices[v3][:faces].include? [v2, v1].sort
    @vertices[v3][:faces].delete [v2, v1].sort
  end

  def delete_line(v1, v2)
    raise "data corruption detected, #{v2} is not in #{v1}'s associated list" unless @vertices[v1][:associated_vertices].include?(v2)
    raise "data corruption detected, #{v1} is not in #{v2}'s associated list" unless @vertices[v2][:associated_vertices].include?(v1)

    @vertices[v1][:associated_vertices].delete v2
    @vertices[v2][:associated_vertices].delete v1
  end

  def get_associated_face_vertices(id)
    raise "no such vertex #{id}" unless @vertices[id]
    @vertices[id][:faces]
  end

  def get_associated_vertex_ids(id)
    raise "no such vertex #{id}" unless @vertices[id]
    @vertices[id][:associated_vertices]
  end

  def modify_face(v1, v2, src, dst)
    raise "vertex #{src} is not on face #{[v1, v2]}" unless @vertices[src][:faces].include?([v1, v2].sort)
    @vertices[src][:faces].delete [v1, v2].sort
    raise "vertex #{dst} is on face #{[v1, v2]}" if @vertices[dst][:faces].include?([v1, v2].sort)
    @vertices[dst][:faces] << [v1, v2].sort

    raise "vertex #{v1} is not on face #{[src, v2]}" unless @vertices[v1][:faces].include?([src, v2].sort)
    @vertices[v1][:faces].delete [v2, src].sort
    raise "vertex #{v1} is on face #{[dst, v2]}" if @vertices[v1][:faces].include?([dst, v2].sort)
    @vertices[v1][:faces] << [v2, dst].sort

    raise "vertex #{v2} is not on face #{[v1, src]}" unless @vertices[v2][:faces].include?([v1, src].sort)
    @vertices[v2][:faces].delete [v1, src].sort
    raise "vertex #{v2} is on face #{[v1, dst]}" if @vertices[v2][:faces].include?([v1, dst].sort)
    @vertices[v2][:faces] << [v1, dst].sort
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
      str += "vertex #{id}, faces: #{v[:faces].map{ |x,y| "[#{x}, #{y}]" }.join(' ')}\n\tassociated: #{v[:associated_vertices].sort.join(' ')}\n"
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
    vs = [v1, v2, v3].sort
    @faces[vs[0]] = {} unless @faces[vs[0]]
    @faces[vs[0]][vs[1]] = {} unless @faces[vs[0]][vs[1]]
    @faces[vs[0]][vs[1]][vs[2]] = { vertices: vs }
  end

  def delete_face(v1, v2, v3)
    vs = [v1, v2, v3].sort
    raise "trying to delete non-existing face #{[v1, v2, v3]}" unless @faces[vs[0]] && @faces[vs[0]][vs[1]] && @faces[vs[0]][vs[1]][vs[2]]
    ret = @faces[vs[0]][vs[1]].delete vs[2]
    @faces[vs[0]].delete vs[1] if @faces[vs[0]][vs[1]].size == 0
    @faces.delete vs[0] if @faces[vs[0]].size == 0
    ret
  end

  def modify_face(v1, v2, src, dst)
    face = delete_face(v1, v2, src)
    face[:vertices].delete src
    if face[:vertices].include?(dst)
      raise "trying to add existing vertex #{src} on face #{[v1, v2, src]}"
    end
    face[:vertices] << dst
    add_face(*face[:vertices])
  end

  def each_face(&block)
    raise 'no block given' unless block
    @faces.each do |v1, v|
      v.each do |v2, vv|
        vv.each do |v3, face|
          block.call(v1, v2, v3, face)
        end
      end
    end
  end

  def to_obj(v_mappings)
    str = ''
    total_size = @faces.size
    i = 0
    each_face do |v1, v2, v3, face|
      puts "f #{v1} #{v2} #{v3}" if VERBOSE > V_NORMAL
      str += "f #{face[:vertices].map { |x| v_mappings[x] ? v_mappings[x] + 1 : (raise "no mapping #{x}") }.join(' ')}\n"
      puts "formatting faces #{(100.0 * i / total_size).round(2)}%" if i == (total_size * 0.01).round && VERBOSE >= V_NORMAL
      i += 1
    end
    puts 'formatting faces done' if VERBOSE >= V_NORMAL
    str
  end
  def dump_to_s
    str = "faces\n"
    each_face do |_v1, _v2, _v3, f|
      str += "\tface #{f[:vertices].sort.join(' ')}\n"
    end
    str
  end

  def get(v1, v2, v3)
    vs = [v1, v2, v3].sort
    unless @faces[vs[0]] && @faces[vs[0]][vs[1]] && @faces[vs[0]][vs[1]][vs[2]]
      raise "trying to get non-existing face #{[v1, v2, v3]}"
    end
    @faces[vs[0]][vs[1]][vs[2]]
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
    f1 = @vertices.get_associated_face_vertices(src).map { |x| (x + [src]).sort }
    f2 = @vertices.get_associated_face_vertices(dst).map { |x| (x + [dst]).sort }
    faces_to_delete = f1 & f2
    faces_to_modify = f1 - f2
    faces_that_has_changed = faces_to_modify
    # after here, f1, f2 are invalid
    faces_to_delete.each do |vs|
      @faces.delete_face(*vs)
      @vertices.delete_face(*vs)
    end
    faces_to_modify.each do |vs|
      raise 'parameter error' unless vs.include?(src)
      @faces.modify_face(*(vs-[src]), src, dst)
      @vertices.modify_face(*(vs-[src]), src, dst)
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