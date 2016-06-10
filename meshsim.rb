#!/usr/bin/env ruby
require 'matrix'
require 'set'
require 'optparse'
require 'narray'
require_relative 'deletable_heap'
require_relative 'lib/fast_4d_matrix/fast_4d_matrix'

module MeshSim
  V_DBG = 10
  V_VERBOSE = 5
  V_NORMAL = 1
  V_SILENT = 0

  $verbose_level = V_SILENT
  $safe_on = true

  module MatrixMathMixinFast
    def calculate_kp(v1, v2, v3)
      Fast4DMatrix::Matrix4Sym.from_face(
          Fast4DMatrix::Vec3.from_a(*get_vec(v1)),
          Fast4DMatrix::Vec3.from_a(*get_vec(v2)),
          Fast4DMatrix::Vec3.from_a(*get_vec(v3)))
    end
    def delta(faces_obj, src_id, dst_id)
      dst_vertex = get_vec(dst_id)
      vec3 = Fast4DMatrix::Vec3.from_a(*dst_vertex)
      faces = get_associated_face_vertices(src_id)
      sum_of_kps = Fast4DMatrix::Matrix4Sym.zero
      faces.each do |v1, v2|
        sum_of_kps.add! faces_obj.get_kp(v1, v2, src_id)
      end
      sum_of_kps.delta(vec3)
    end
  end

  module MatrixMathMixinSlow
    def calculate_kp(v1, v2, v3)
      vec1, vec2, vec3 = *[v1, v2, v3].map { |x| Vector[*get_vec(x)] }
      n = (vec1 - vec2).cross(vec1 - vec3)
      # (m.dot m.transpose).to_f
      raise "#{[vec1, vec2, vec3]} cannot make a face" if n.r == 0
      nn = n.normalize
      # p = Matrix[[nn[0], nn[1], nn[2], -nn.dot(vec1)]]
      # p.t * p
      p = Matrix[nn.to_a + [-nn.dot(vec1)]]
      p.t * p
    end
    def delta(faces_obj, src_id, dst_id)
      dst_vertex = get_vec(dst_id)

      # 三维行向量变成四维行向量
      matrix_dst_vertex = Matrix[*dst_vertex.to_a.map { |x| [x] }, [1]]

      faces = get_associated_face_vertices(src_id)
      sum_of_kps = Matrix.zero(4, 4)
      faces.each do |v1, v2|
        sum_of_kps += faces_obj.get_kp(v1, v2, src_id)
      end
      (matrix_dst_vertex.t * sum_of_kps * matrix_dst_vertex).to_a.first.first
    end
  end

  class Vertices
    include MatrixMathMixinFast

    def initialize
      @vertices = {}
    end

    def add_vertex(id, point)
      @vertices[id] = { vector: point, faces: [], associated_vertices: [] }
    end

    def attach_to_face(face_id, v1, v2, v3)
      raise "vertex #{v1} already on face #{face_id}" if $safe_on && @vertices[v1][:faces].include?(face_id)
      @vertices[v1][:faces] << [v2, v3].sort
      @vertices[v1][:associated_vertices] << v2 unless @vertices[v1][:associated_vertices].include?(v2)
      @vertices[v1][:associated_vertices] << v3 unless @vertices[v1][:associated_vertices].include?(v3)

      raise "vertex #{v1} already on face #{face_id}" if $safe_on && @vertices[v2][:faces].include?(face_id)
      @vertices[v2][:faces] << [v1, v3].sort
      @vertices[v2][:associated_vertices] << v1 unless @vertices[v2][:associated_vertices].include?(v1)
      @vertices[v2][:associated_vertices] << v3 unless @vertices[v2][:associated_vertices].include?(v3)

      raise "vertex #{v1} already on face #{face_id}" if $safe_on && @vertices[v3][:faces].include?(face_id)
      @vertices[v3][:faces] << [v1, v2].sort
      @vertices[v3][:associated_vertices] << v2 unless @vertices[v3][:associated_vertices].include?(v2)
      @vertices[v3][:associated_vertices] << v1 unless @vertices[v3][:associated_vertices].include?(v1)
    end

    def get_vec(id)
      raise "no such vertex #{id}" if $safe_on && !@vertices[id]
      @vertices[id][:vector]
    end

    # def moving_vec(id, vec)
    #   raise "no such vertex #{id}" unless @vertices[id]
    #   @vertices[id][:vector] = vec
    # end

    def delete_vertex(id)
      raise "no such vertex #{id}" if $safe_on && !@vertices[id]
      @vertices.delete id
    end

    def delete_face(v1, v2, v3)
      v1, v2, v3 = [v1, v2, v3].sort
      raise "vertex #{v1} is not on face #{[v2, v3]}" unless !$safe_on || @vertices[v1][:faces].include?([v2, v3])
      @vertices[v1][:faces].delete [v2, v3]
      raise "vertex #{v2} is not on face #{[v1, v3]}" unless !$safe_on || @vertices[v2][:faces].include?([v1, v3])
      @vertices[v2][:faces].delete [v1, v3]
      raise "vertex #{v3} is not on face #{[v1, v2]}" unless !$safe_on || @vertices[v3][:faces].include?([v1, v2])
      @vertices[v3][:faces].delete [v1, v2]
    end

    def delete_line(v1, v2)
      raise "data corruption detected, #{v2} is not in #{v1}'s associated list" unless !$safe_on || @vertices[v1][:associated_vertices].include?(v2)
      raise "data corruption detected, #{v1} is not in #{v2}'s associated list" unless !$safe_on || @vertices[v2][:associated_vertices].include?(v1)

      @vertices[v1][:associated_vertices].delete v2
      @vertices[v2][:associated_vertices].delete v1
    end

    def get_associated_face_vertices(id)
      raise "no such vertex #{id}" unless !$safe_on || @vertices[id]
      @vertices[id][:faces]
    end

    def get_associated_vertex_ids(id)
      raise "no such vertex #{id}" unless !$safe_on || @vertices[id]
      @vertices[id][:associated_vertices]
    end

    # change face [v1, v2, src] -> [v1, v2, dst]
    # if [v1, v2, dst] exists, delete face [v1, v2, src] and returns false
    #
    def modify_face!(v1, v2, src, dst)
      v1, v2 = v2, v1 if v1 > v2
      src1, v21 = src < v2 ? [src, v2] : [v2, src]
      src2, v12 = src < v1 ? [src, v1] : [v1, src]

      dst3, v23 = dst < v2 ? [dst, v2] : [v2, dst]
      dst4, v14 = dst < v1 ? [dst, v1] : [v1, dst]

      raise "vertex #{src} is not on face #{[v1, v2]}" unless !$safe_on || @vertices[src][:faces].include?([v1, v2])
      @vertices[src][:faces].delete [v1, v2]
      raise "vertex #{v1} is not on face #{[src, v2]}" unless !$safe_on || @vertices[v1][:faces].include?([src1, v21])
      @vertices[v1][:faces].delete [src1, v21]
      raise "vertex #{v2} is not on face #{[v1, src]}" unless !$safe_on || @vertices[v2][:faces].include?([src2, v12])
      @vertices[v2][:faces].delete [src2, v12]

      if @vertices[dst][:faces].include?([v1, v2])
        nil
      else
        @vertices[dst][:faces] << [v1, v2]
        raise "vertex #{v1} is on face #{[dst, v2]}" if $safe_on && @vertices[v1][:faces].include?([dst3, v23])
        @vertices[v1][:faces] << [dst3, v23]
        raise "vertex #{v2} is on face #{[v1, dst]}" if $safe_on && @vertices[v2][:faces].include?([dst4, v14])
        @vertices[v2][:faces] << [dst4, v14]
        [v1, v2, dst]
      end
    end

    # raise ArgumentError if v1-dst exists
    def modify_line!(v1, src, dst)
      raise "vertex #{src} is not associated with #{v1}" unless !$safe_on || @vertices[src][:associated_vertices].include?(v1)
      @vertices[v1][:associated_vertices].delete src
      raise ArgumentError, "vertex #{dst} is associated with #{v1}" if @vertices[dst][:associated_vertices].include?(v1)
      @vertices[v1][:associated_vertices] << dst

      @vertices[dst][:associated_vertices] << v1

      raise "vertex #{v1} is not associated with #{src}" unless !$safe_on || @vertices[src][:associated_vertices].include?(v1)
      @vertices[src][:associated_vertices].delete v1
    end

    def delete_associated_vertex!(id, to_delete)
      raise "vertex #{to_delete} is not associated with #{id}" unless !$safe_on || @vertices[to_delete][:associated_vertices].include?(id)
      @vertices[id][:associated_vertices].delete to_delete
    end

    def to_obj(io)
      v_index = 0
      v_mappings = {}
      total_size = @vertices.size
      i = 0
      stepping_index = [(0.1 * total_size).round, 1].max
      @vertices.each do |id, v|
        v_mappings[id] = v_index
        v_index += 1
        io.puts "v #{v[:vector].to_a.map { |x| x.to_s }.join(' ')}"
        puts "formatting vertices #{(100.0 * i / total_size).round(2)}%..." if i % stepping_index == 0 && $verbose_level >= V_NORMAL
        i += 1
      end
      puts "formatting vertices done\n\n" if $verbose_level >= V_NORMAL
      io.puts "\n"
      v_mappings
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
        puts e if $verbose_level > V_NORMAL
      end
      begin
        add_line(v1, v3)
      rescue ArgumentError => e
        puts e if $verbose_level > V_NORMAL
      end
      begin
        add_line(v3, v2)
      rescue ArgumentError => e
        puts e if $verbose_level > V_NORMAL
      end
    end
    # used only for initializing
    def add_line(v1, v2)
      raise "two same vertices cannot make a line #{v1}" if $safe_on && v1 == v2
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
      if !$safe_on || get(v1, v2)
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
      puts "delta unchanged for line #{[v1, v2]}, delta: #{delta}" if delta == line[:delta] && $verbose_level >= V_NORMAL

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
      raise "trying to delete non-existing face #{[v1, v2, v3]}" unless !$safe_on || (@faces[vs[0]] && @faces[vs[0]][vs[1]] && @faces[vs[0]][vs[1]][vs[2]])
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
        puts e if $verbose_level >= V_VERBOSE
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

    def count_face_on
      @faces.reduce(0) { |sum, item1| sum + item1.last.reduce(0) { |s1,item2| s1 + item2.last.size } }
    end

    def to_obj(v_mappings, io)
      total_size = 0
      each_face { total_size += 1 }
      i = 0
      stepping_index = [(total_size * 0.1).round, 1].max
      each_face do |v1, v2, v3, face|
        puts "f #{v1} #{v2} #{v3}" if $verbose_level > V_NORMAL
        io.puts "f #{face[:vertices].map { |x| v_mappings[x] ? v_mappings[x] + 1 : (raise "no mapping #{x}") }.join(' ')}"
        puts "formatting faces #{(100.0 * i / total_size).round(2)}%" if i % stepping_index == 0  && $verbose_level >= V_NORMAL
        i += 1
      end
      puts "formatting faces done\n\n" if $verbose_level >= V_NORMAL
      i
    end
    def dump_to_s
      str = "faces\n"
      each_face do |_v1, _v2, _v3, f|
        str += "\tface #{f[:vertices].sort.join(' ')}\n"
      end
      str
    end

    def get(v1, v2, v3)
      v1, v2, v3 = [v1, v2, v3].sort
      raise "trying to get non-existing face #{[v1, v2, v3]}" unless !$safe_on || @faces[v1] && @faces[v1][v2] && @faces[v1][v2][v3]
      @faces[v1][v2][v3]
    end

    def recalculate_kp!(vertices, v1, v2, v3)
      get(v1, v2, v3)[:kp] = vertices.calculate_kp(v1, v2, v3)
    end

    def get_kp(v1, v2, v3)
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
      File.open(file_path, 'r') do |f|
        f.readlines.each do |line|
          type, *rest = line.split(' ')
          case type
            when 'v'
              @vertices.add_vertex(v_id, rest.map { |x| x.to_f })
              v_id += 1
            when 'f'
              vs = rest.map { |x| x.to_i - 1 }
              @lines.add_lines_by_face(*vs)
              face_id = @faces.add_face(*vs)
              @vertices.attach_to_face(face_id, *vs)
            else
              'ignore it'
          end
        end
      end

      @faces.each_face do |v1, v2, v3, _|
        @faces.recalculate_kp!(@vertices, v1, v2, v3)
      end
      @lines.each_line do |v1, v2, _line|
        @lines.set_delta_and_push_to_heap!(v1, v2, @vertices.delta(@faces, v1, v2))
      end
    end

    def merge_vertex(src, dst)
      puts "merging #{src} -> #{dst}" if $verbose_level >= V_NORMAL

      # merging_point = (@vertices.get_vec(src) + @vertices.get_vec(dst)) / 2
      # @vertices.moving_vec(dst, merging_point)

      # modify and delete faces
      f1 = @vertices.get_associated_face_vertices(src).map { |x| (x + [src]).sort }
      f2 = @vertices.get_associated_face_vertices(dst).map { |x| (x + [dst]).sort }
      faces_to_delete = f1 & f2
      faces_to_modify = f1 - f2
      faces_to_recalculate = []#f2 - f1
      faces_that_has_changed = []
      # after here, f1, f2 are invalid
      faces_to_delete.each do |vs|
        @faces.delete_face!(*vs)
        @vertices.delete_face(*vs)
      end
      # +faces_to_modify+ 是需要修改的faces, 注意, 有可能修改后和已有面重合, 这种情况删除该修改前的面
      faces_to_modify.each do |vs|
        raise 'parameter error' unless !$safe_on || vs.include?(src)
        @faces.modify_face!(*(vs-[src]), src, dst)

        # new_face.nil? == true 代表修改后和已有面重合
        new_face = @vertices.modify_face!(*(vs-[src]), src, dst)
        faces_that_has_changed << new_face if new_face
      end
      (faces_that_has_changed + faces_to_recalculate).each do |vs|
        @faces.recalculate_kp!(@vertices, *vs)
      end

      # modify and delete lines
      lines_that_has_changed = Set.new
      vertices_on_the_other_side = @vertices.get_associated_vertex_ids(src)
      raise "#{dst} is not associated with #{src}" unless !$safe_on || vertices_on_the_other_side.include?(dst)
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

      (faces_that_has_changed + faces_to_recalculate).each do |vs|
        lines_that_has_changed << [vs[0], vs[1]].sort
        lines_that_has_changed << [vs[0], vs[2]].sort
        lines_that_has_changed << [vs[1], vs[2]].sort
      end

      lines_that_has_changed.each do |v1, v2|
        @lines.update_delta!(v1, v2, @vertices.delta(@faces, v1, v2))
        puts "recalculated delta for #{[v1, v2]}" if $verbose_level > V_NORMAL
      end
      # 需要更新包含src的面上的所有线段的delta

      @lines.delete_line(src, dst)
      @vertices.delete_line(src, dst)

      @vertices.delete_vertex(src)
    end
    def select_a_best_line
      @lines.select_a_best_line
    end

    def heap
      @lines.heap
    end

    def line_count
      @lines.heap.size
    end

    def count_face
      @faces.count_face_on
    end

    def write_to_file(file_path)
      File.open(file_path, 'w') do |f|
        v_mappings = @vertices.to_obj(f)
        puts "vertices: #{v_mappings.size}" if $verbose_level > MeshSim::V_SILENT
        face_count = @faces.to_obj(v_mappings, f)
        puts "faces: #{face_count}" if $verbose_level > MeshSim::V_SILENT
      end
    end

    def face_count
      @faces.count
    end

    def dump_print
      puts @vertices.dump_to_s
      puts @lines.dump_to_s
      puts @faces.dump_to_s
      puts
    end
  end

  def self.meshsim(infile, outfile, rate, verbose, prof = false, safe_on = true)
    $verbose_level = verbose
    $safe_on = safe_on

    if prof
      require 'ruby-prof'
      # profile the code
      RubyProf.start
    end

    obj = ObjectManager.new(infile)

    puts 'initialized' if $verbose_level > V_SILENT
    original_face_count = obj.face_count
    original_line_count = obj.line_count
    puts "original face count #{original_face_count}" if $verbose_level > V_SILENT
    target_face_count = original_face_count * rate
    target_line_count = target_face_count * 1.5
    # obj.dump_print
    i = 0
    while obj.line_count > target_line_count do
      # raise 'data corruption detected' unless obj.count_face == obj.face_count
      v1, v2 = obj.select_a_best_line
      obj.merge_vertex(v1, v2)
      # obj.dump_print
      puts "simplifying #{(100.0 * obj.line_count / original_line_count).round(2)}" if $verbose_level > V_SILENT && i % 100 == 0
      i += 1
    end

    obj.write_to_file(outfile)

    if prof
      result = RubyProf.stop
      # print a flat profile to text
      printer = RubyProf::FlatPrinter.new(result)
      printer.print(STDOUT)
      require 'byebug'
      byebug
      exit!
    end
  end

end


