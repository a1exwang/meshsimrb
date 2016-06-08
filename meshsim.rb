require 'pp'
require 'matrix'
require 'algorithms'

@vertices = {}
@faces = {}
@lines = {}
@line_count = 0

@verbose = true

def dump_print
  puts 'vertices'
  pp @vertices.map { |k, v| { id: k, faces: v[:faces], other_vertices: v[:other_vertices] } }
  puts 'faces:'
  pp @faces.map { |k, v| [k, v[:vertices]]}
  # puts 'lines:'
  # pp @lines
  # puts "line count: #{line_count}"
  puts
end

def get_vertex(id)
  @vertices[id]
end

def get_face_ids_by_vertex(id)
  @vertices[id][:faces].dup
end

def get_other_vertex_ids(id)
  @vertices[id][:other_vertices].dup
end

def get_face(id)
  @faces[id]
end

def get_kp(id)
  @faces[id][:kp]
end

def get_line(v1, v2)
  v1, v2 = v2, v1 if v1 > v2
  @lines[v1][v2]
end

def add_vertex(id, vertex)
  @vertices[id] = vertex
end

def add_face(face)
  id = @faces.keys.size
  @faces[id] = face
  id
end

def create_line(i1, i2)
  put_line(i1, i2, vertices: [i1, i2])
  @line_count += 1
  get_vertex(i1)[:other_vertices] << i2 unless get_vertex(i1)[:other_vertices].include?(i2)
  get_vertex(i2)[:other_vertices] << i1 unless get_vertex(i2)[:other_vertices].include?(i1)
end

def put_line(i1, i2, line)
  i1, i2 = i2, i1 if i1 > i2
  @lines[i1] = {} unless @lines[i1]
  @lines[i1][i2] = line
end

def remove_vertex(id)
  @vertices.delete id
end
def remove_line(v1, v2)
  v1, v2 = v2, v1 if v1 > v2
  if get_vertex(v1)
    get_vertex(v1)[:other_vertices].delete v2
    puts "deleting line other vertex #{v2} from vertex #{v1}" if @verbose
  end
  if get_vertex(v2)
    get_vertex(v2)[:other_vertices].delete v1
    puts "deleting line other vertex #{v2} from vertex #{v1}" if @verbose
  end

  raise "removing non-existing line #{v1}-#{v2}" unless @lines[v1] && @lines[v1][v2]

  line = @lines[v1][v2]
  line[:deleted] = true
  @lines[v1].delete v2
  if @lines[v1].size == 0
    @lines.delete v1
  end
  @line_count -= 1
end
def remove_face(id)
  face = get_face(id)
  face[:vertices].each do |v|
    puts "deleting face #{id} from vertex #{v}" if @verbose
    vt = get_vertex(v)
    unless vt
      raise 'vertex on face is nil'
    end
    vt[:faces].delete id # if get_vertex(v)
  end

  @faces.delete id
end

def each_line(&block)
  index = 0
  @lines.each do |i1, v|
    v.each do |i2, line|
      block.call(i1, i2, line, index)
      index += 1
    end
  end
end

def line_count
  @line_count
end

# i1, i2, i3, vertex id
# calculate kp matrix
def kp(i1, i2, i3)
  v1, v2, v3 = get_vertex(i1), get_vertex(i2), get_vertex(i3)
  n = (v1[:vector]-v2[:vector]).cross(v1[:vector]-v3[:vector])
  if n.r == 0
    Matrix.identity(4)
  else
    nn = n.normalize
    p = Matrix[[nn[0]], [nn[1]], [nn[2]], [-nn.dot(v1[:vector])]]
    p * p.t
  end
end

def delta(line)
  dst_vertex = get_vertex(line[:vertices].last)[:vector]
  src_id = line[:vertices].first

  matrix_dst_vertex = Matrix[*dst_vertex.to_a.map { |x| [x] }, [1]]

  faces = get_face_ids_by_vertex(src_id)
  sum_of_kps = Matrix.zero(4, 4)
  faces.each do |f|
    sum_of_kps += get_kp(f)
  end
  (matrix_dst_vertex.t * sum_of_kps * matrix_dst_vertex).to_a.first.first
end

# 初始化所有点, 面
# 点: { vector: Vector[x, y, z], faces: [face_id, ..], lines: [line_id, ..] }
# 面: { vertices: [v_id, ...], kp: Matrix[] }
# 线: { vertices: [v_id, ...], delta: 1.0 }
v_id = 0
File.read('test_data/dinosaur.2k.obj').split("\n").each do |line|
  type, *rest = line.split(' ')
  case type
    when 'v'
      add_vertex(v_id, id: v_id, vector: Vector[*(rest.map { |x| x.to_f })], faces: [], other_vertices: [])
      v_id += 1
    when 'f'
      vs = rest.map { |x| x.to_i - 1 }
      face_id = add_face vertices: vs
      vs.each { |v| get_vertex(v)[:faces] << face_id }
  end
end

# initialize lines
# 所有线, 以id小的点为起点, 防止重复
@faces.each do |_id, face|
  i1, i2, i3 = face[:vertices]

  # calc kps
  face[:kp] = kp(i1, i2, i3)

  create_line(i1, i2)
  create_line(i1, i3)
  create_line(i2, i3)
end

@heap = []

puts "total lines: #{line_count}"
each_line do |_v1, _v2, line, index|
  line[:delta] = delta(line)
  @heap.push(line)
  puts "current #{index}, #{(100.0*index/line_count).round(2)}%" if index % 300 == 0
end
puts 'initialized'

# src-i2 -> tgt-i2
# tgt[line] << i2
# i2[line] << tgt
def modify_line(src, i2, tgt)
  # change line vertices
  line = get_line(src, i2)
  line[:vertices] = [tgt, i2].sort
  line[:delta] = delta(line)

  # move line index
  s, e = src > i2 ? [i2, src] : [src, i2]
  unless @lines[s]
    puts "@lines[s] is nil, s=#{s}"
  end
  @lines[s].delete e
  put_line(i2, tgt, line)

  # update line index in vertex
  get_vertex(i2)[:other_vertices].delete src
  get_vertex(i2)[:other_vertices] << tgt unless get_vertex(i2)[:other_vertices].include?(tgt)

  # move src adjacent to tgt adjacent
  tgt_adj = get_vertex(tgt)[:other_vertices]
  src_adj = get_vertex(src)[:other_vertices]
  (src_adj - tgt_adj).each do |v|
    next if tgt == v
    get_vertex(v)[:other_vertices].delete src
    get_vertex(v)[:other_vertices] << tgt unless get_vertex(v)[:other_vertices].include?(tgt)
    get_vertex(tgt)[:other_vertices] << v
  end
end

def modify_face(face_id, v1, v2)
  vs = get_face(face_id)[:vertices]
  vs.each_with_index do |vid, index|
    vs[index] = v2 if vid == v1
  end
  get_vertex(v1)[:faces].delete face_id
  if get_vertex(v2)[:faces][face_id]
    raise "vertex #{v2} should not on face #{face_id}"
  end
  get_vertex(v2)[:faces] << face_id
end

def merge_vertex(i1, i2)
  # merge i1 -> i2
  raise "vertex #{i1} does not exist" unless get_vertex(i1)
  raise "vertex #{i2} does not exist" unless get_vertex(i2)

  # update face
  faces1 = get_face_ids_by_vertex(i1)
  faces2 = get_face_ids_by_vertex(i2)

  faces_to_delete = faces1 & faces2
  faces_to_modify = faces1 - faces2

  faces_to_delete.each do |i|
    remove_face(i)
    puts "deleting face: #{i}" if @verbose
  end
  faces_to_modify.each do |i|
    puts "modifying face: #{i}. vertex from #{i1} -> #{i2}" if @verbose
    modify_face(i, i1, i2)
  end

  # update lines
  lines_to_modify = get_other_vertex_ids(i1)
  lines_to_modify.each do |other_id|
    if other_id == i2
      puts "removing line #{i1}-#{other_id}" if @verbose
      remove_line(i1, i2)
    else
      puts "modifying line #{i1}-#{other_id} -> #{i2}-#{other_id}" if @verbose
      modify_line(i1, other_id, i2)
    end
  end

  remove_vertex(i1)
end

# start merging
face_count = @faces.size
target_face_count = (face_count * 0.1).to_i
i = 0
@heap.sort! { |x, y| y[:delta] <=> x[:delta] }
# dump_print if @verbose
while face_count > target_face_count
  # line = @heap.pop
  line = nil
  i = 0
  until line
    line = @lines[@lines.keys[i]]&.first&.last
    i += 1
  end

  unless line
    puts 'all faces have gone'
    break
  end
  v1, v2 = line[:vertices]
  if line[:deleted]
    puts "skipping deleted line #{v1} -> #{v2}\n"
    next
  end

  puts "merging #{v1} -> #{v2}"
  merge_vertex(v1, v2)
  puts
  face_count = @faces.size
  i += 1
  puts "current face count #{face_count}, target #{target_face_count}" if face_count % 500 == 0
  # dump_print if @verbose
end

def output(vertices, faces)
  str = ''
  v_index = 0
  v_mappings = {}
  vertices.each do |id, v|
    v_mappings[id] = v_index
    v_index += 1
    str += "v #{v[:vector].to_a.map { |x| x.to_s }.join(' ')}\n"
  end
  str += "\n"
  faces.each do |_id, face|
    v1, v2, v3 = face[:vertices].to_a
    puts "f #{v1} #{v2} #{v3}" if @verbose

    str += "f #{face[:vertices].to_a.map { |x| v_mappings[x] ? v_mappings[x] : (raise "no mapping #{x}") }.join(' ')}\n"
  end
  str
end

File.write('a.obj', output(@vertices, @faces))