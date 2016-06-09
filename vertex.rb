require 'matrix'
require 'set'
require_relative 'deletable_heap'

V_DBG = 10
V_VERBOSE = 5
V_NORMAL = 1
V_SILENT = 0

VERBOSE = V_SILENT

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

  def get_vec(id)
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

  # change face [v1, v2, src] -> [v1, v2, dst]
  # if [v1, v2, dst] exists, delete face [v1, v2, src] and returns false
  def modify_face!(v1, v2, src, dst)
    raise "vertex #{src} is not on face #{[v1, v2]}" unless @vertices[src][:faces].include?([v1, v2].sort)
    @vertices[src][:faces].delete [v1, v2].sort
    raise "vertex #{v1} is not on face #{[src, v2]}" unless @vertices[v1][:faces].include?([src, v2].sort)
    @vertices[v1][:faces].delete [v2, src].sort
    raise "vertex #{v2} is not on face #{[v1, src]}" unless @vertices[v2][:faces].include?([v1, src].sort)
    @vertices[v2][:faces].delete [v1, src].sort

    if @vertices[dst][:faces].include?([v1, v2].sort)
      nil
    else
      @vertices[dst][:faces] << [v1, v2].sort
      raise "vertex #{v1} is on face #{[dst, v2]}" if @vertices[v1][:faces].include?([dst, v2].sort)
      @vertices[v1][:faces] << [v2, dst].sort
      raise "vertex #{v2} is on face #{[v1, dst]}" if @vertices[v2][:faces].include?([v1, dst].sort)
      @vertices[v2][:faces] << [v1, dst].sort
      [v1, v2, dst]
    end
  end

  # raise ArgumentError if v1-dst exists
  def modify_line!(v1, src, dst)
    raise "vertex #{src} is not associated with #{v1}" unless @vertices[src][:associated_vertices].include?(v1)
    @vertices[v1][:associated_vertices].delete src
    raise ArgumentError, "vertex #{dst} is associated with #{v1}" if @vertices[dst][:associated_vertices].include?(v1)
    @vertices[v1][:associated_vertices] << dst

    @vertices[dst][:associated_vertices] << v1

    raise "vertex #{v1} is not associated with #{src}" unless @vertices[src][:associated_vertices].include?(v1)
    @vertices[src][:associated_vertices].delete v1
  end

  def delete_associated_vertex!(id, to_delete)
    raise "vertex #{to_delete} is not associated with #{id}" unless @vertices[to_delete][:associated_vertices].include?(id)
    @vertices[id][:associated_vertices].delete to_delete
  end

  def to_obj
    str = ''
    v_index = 0
    v_mappings = {}
    total_size = @vertices.size
    i = 0
    stepping_index = [(0.1 * total_size).round, 1].max
    @vertices.each do |id, v|
      v_mappings[id] = v_index
      v_index += 1
      str += "v #{v[:vector].to_a.map { |x| x.to_s }.join(' ')}\n"
      puts "formatting vertices #{(100.0 * i / total_size).round(2)}%..." if i % stepping_index == 0 && VERBOSE >= V_NORMAL
      i += 1
    end
    puts "formatting vertices done\n\n" if VERBOSE >= V_NORMAL
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

  def calculate_kp(v1, v2, v3)
    vec1, vec2, vec3 = *[v1, v2, v3].map { |x| get_vec(x) }
    n = (vec1 - vec2).cross(vec1 - vec3)
    raise "#{[vec1, vec2, vec3]} cannot make a face" if n.r == 0
    nn = n.normalize
    p = Matrix[[nn[0]], [nn[1]], [nn[2]], [-nn.dot(vec1)]]
    p * p.t
  end
end

class Lines
  def initialize
    @lines = {}
    @heap = DeletableHeap.new { |x, y| x[:delta] <=> y[:delta] }
  end
  def heap
    @heap
  end
  def get_delta(v1, v2)
    get(v1, v2)[:delta]
  end

  # used only for initializing
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
  # used only for initializing
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
      @heap.delete(ret[:heap_ref])
      @lines.delete v1 if @lines[v1].size == 0
      ret
    else
      raise "trying to delete non-existing line #{v1}-#{v2}"
    end
  end

  def modify_line!(v1, src, dst)
    # raise "trying to delete non-existing line #{v1}-#{v2}" unless get(v1, src)
    # s, e = v1 < src ? [v1, src] : [src, v1]
    # line = @lines[s].delete e
    # @lines.delete s if @lines[s].size == 0
    line = delete_line(v1, src)
    line[:vertices] = [v1, dst]
    # @heap.delete(line[:heap_ref])

    s, e = v1 < dst ? [v1, dst] : [dst, v1]
    return nil if @lines[s] && @lines[s][e]
    line[:heap_ref] = @heap.push(line)
    @lines[s] = {} unless @lines[s]
    @lines[s][e] = line
    [s, e]
  end

  def select_a_best_line
    # @lines.first.last.first.last[:vertices]
    line = @heap.peek
    line[:vertices]
  end

  def dump_to_s
    str = "lines\n"
    each_line do |v1, v2, l|
      str += "\t#{v1}-#{v2}\n"
    end
    str
  end

  def set_delta_and_push_to_heap!(v1, v2, delta)
    line = get(v1, v2)
    line[:delta] = delta
    line[:heap_ref] = @heap.push line
  end

  def update_delta!(v1, v2, delta)
    line = get(v1, v2)
    puts "delta unchanged for line #{[v1, v2]}, delta: #{delta}" if delta == line[:delta] && VERBOSE >= V_NORMAL

    @heap.delete(line[:heap_ref])
    line[:delta] = delta
    line[:heap_ref] = @heap.push(line)
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
  attr_reader :count
  def self.check(v1, v2, v3, u1, u2, u3)
    [v1, v2, v3].sort == [u1, u2, u3].sort
  end

  def initialize
    @faces = {}
    @count = 0
  end

  def add_face(v1, v2, v3)
    vs = [v1, v2, v3].sort
    @faces[vs[0]] = {} unless @faces[vs[0]]
    @faces[vs[0]][vs[1]] = {} unless @faces[vs[0]][vs[1]]
    raise ArgumentError, "trying to add existing face #{vs}" if @faces[vs[0]][vs[1]][vs[2]]
    @count += 1
    @faces[vs[0]][vs[1]][vs[2]] = { vertices: [v1, v2, v3] }
  end

  def delete_face!(v1, v2, v3)
    vs = [v1, v2, v3].sort
    raise "trying to delete non-existing face #{[v1, v2, v3]}" unless @faces[vs[0]] && @faces[vs[0]][vs[1]] && @faces[vs[0]][vs[1]][vs[2]]
    ret = @faces[vs[0]][vs[1]].delete vs[2]
    @faces[vs[0]].delete vs[1] if @faces[vs[0]][vs[1]].size == 0
    @faces.delete vs[0] if @faces[vs[0]].size == 0
    @count -= 1
    ret
  end

  def modify_face!(v1, v2, src, dst)
    face = delete_face!(v1, v2, src)

    if face[:vertices].include?(dst)
      raise "trying to add existing vertex #{src} on face #{[v1, v2, src]}"
    end
    face[:vertices].map! { |x| x == src ? dst : x }
    begin
      add_face(*face[:vertices])
    rescue ArgumentError => e
      puts e if VERBOSE >= V_VERBOSE
    end
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
    total_size = 0
    each_face { total_size += 1 }
    i = 0
    stepping_index = [(total_size * 0.1).round, 1].max
    each_face do |v1, v2, v3, face|
      puts "f #{v1} #{v2} #{v3}" if VERBOSE > V_NORMAL
      str += "f #{face[:vertices].map { |x| v_mappings[x] ? v_mappings[x] + 1 : (raise "no mapping #{x}") }.join(' ')}\n"
      puts "formatting faces #{(100.0 * i / total_size).round(2)}%" if i % stepping_index == 0  && VERBOSE >= V_NORMAL
      i += 1
    end
    puts "formatting faces done\n\n" if VERBOSE >= V_NORMAL
    [str, i]
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

  def recalculate_kp!(vertices, v1, v2, v3)
    get(v1, v2, v3)[:kp] = vertices.calculate_kp(v1, v2, v3)
  end

  def kp(v1, v2, v3)
    ret = get(v1, v2, v3)[:kp]
    raise "kp for #{[v1, v2, v3]} has never calculated!" unless ret
    ret
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

    @faces.each_face do |v1, v2, v3, _|
      @faces.recalculate_kp!(@vertices, v1, v2, v3)
    end
    @lines.each_line do |v1, v2, _line|
      @lines.set_delta_and_push_to_heap!(v1, v2, delta(v1, v2))
    end
  end
  def delta(src_id, dst_id)
    dst_vertex = @vertices.get_vec(dst_id)

    # 三维行向量变成四维行向量
    matrix_dst_vertex = Matrix[*dst_vertex.to_a.map { |x| [x] }, [1]]

    faces = @vertices.get_associated_face_vertices(src_id)
    sum_of_kps = Matrix.zero(4, 4)
    faces.each do |v1, v2|
      sum_of_kps += @faces.kp(v1, v2, src_id)
    end
    (matrix_dst_vertex.t * sum_of_kps * matrix_dst_vertex).to_a.first.first
  end

  def merge_vertex(src, dst)
    puts "merging #{src} -> #{dst}" if VERBOSE >= V_NORMAL
    # modify and delete faces
    f1 = @vertices.get_associated_face_vertices(src).map { |x| (x + [src]).sort }
    f2 = @vertices.get_associated_face_vertices(dst).map { |x| (x + [dst]).sort }
    faces_to_delete = f1 & f2
    faces_to_modify = f1 - f2
    faces_that_has_changed = []
    # after here, f1, f2 are invalid
    faces_to_delete.each do |vs|
      @faces.delete_face!(*vs)
      @vertices.delete_face(*vs)
    end
    # +faces_to_modify+ 是需要修改的faces, 注意, 有可能修改后和已有面重合, 这种情况删除该修改前的面
    faces_to_modify.each do |vs|
      raise 'parameter error' unless vs.include?(src)
      @faces.modify_face!(*(vs-[src]), src, dst)

      # new_face.nil? == true 代表修改后和已有面重合
      new_face = @vertices.modify_face!(*(vs-[src]), src, dst)
      faces_that_has_changed << new_face if new_face
    end
    faces_that_has_changed.each do |vs|
      @faces.recalculate_kp!(@vertices, *vs)
    end

    # modify and delete lines
    lines_that_has_changed = Set.new
    vertices_on_the_other_side = @vertices.get_associated_vertex_ids(src)
    raise "#{dst} is not associated with #{src}" unless vertices_on_the_other_side.include?(dst)
    lines_to_modify = vertices_on_the_other_side - [dst]
    lines_to_modify.each do |v2|
      # +line+ is v2-dst
      line = @lines.modify_line!(v2, src, dst)

      if line
        @vertices.modify_line!(v2, src, dst)
        lines_that_has_changed << line.sort
      else
        # we already have v2-dst
        @vertices.delete_associated_vertex!(v2, src)
        # lines_that_has_been_deleted << heap_ref
      end
    end

    faces_that_has_changed.each do |vs|
      lines_that_has_changed << [vs[0], vs[1]].sort
      lines_that_has_changed << [vs[0], vs[2]].sort
      lines_that_has_changed << [vs[1], vs[2]].sort
    end

    lines_that_has_changed.each do |v1, v2|
      @lines.update_delta!(v1, v2, delta(v1, v2))
      puts "recalculated delta for #{[v1, v2]}" if VERBOSE > V_NORMAL
    end
    # 需要更新包含src的面上的所有线段的delta

    @lines.delete_line(src, dst)
    @vertices.delete_line(src, dst)

    @vertices.delete(src)
  end
  def select_a_best_line
    @lines.select_a_best_line
  end

  def heap
    @lines.heap
  end

  def write_to_file(file_path)
    vertices_str, v_mappings = @vertices.to_obj
    puts "vertices: #{v_mappings.size}"
    faces_str, face_count = @faces.to_obj(v_mappings)
    puts "faces: #{face_count}"
    File.write(file_path, vertices_str + faces_str)
  end

  def face_count
    @faces.count
  end

  def dump_print
    puts @vertices.dump_to_s
    puts @lines.dump_to_s
    puts @faces.dump_to_s
  end
end

SIMPLIFICATION_RATE = 0.5

obj = ObjectManager.new('test_data/dinosaur.2k.obj')
original_face_count = obj.face_count
target_face_count = original_face_count * SIMPLIFICATION_RATE

# obj.dump_print
while obj.face_count > target_face_count do
  v1, v2 = obj.select_a_best_line
  # begin
  obj.merge_vertex(v1, v2)
  # rescue
  #   puts $!
  # end
  # obj.dump_print
  # puts
end

obj.write_to_file('a.obj')