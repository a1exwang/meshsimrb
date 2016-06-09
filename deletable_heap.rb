
class DeletableHeap
  attr_reader :size
  # if when x - y < 0, comparator.call(x, y) == -1
  # little-top-heap
  def initialize(&comparator)
    raise 'no block given' unless comparator
    @comparator = comparator
    @array = []
    @size = 0
  end

  def push(item)
    if @size == @array.size
      @array += [nil] * (@array.size + 1)
    end
    ret = { index: @size, data: item }
    @array[@size] = ret
    @size += 1
    percolate_up(@size - 1)
    ret
  end

  def pop
    raise 'heap is empty' if @size <= 0
    ret = @array[0]
    swap(0, @size-1) if 1 != @size
    @array[@size-1] = nil
    @size -= 1
    percolate_down(0) if @size > 0
    ret[:data]
  end

  def delete(item)
    raise 'data corruption detected' unless item[:index].is_a?(Integer)
    index = item[:index]
    if index >= @size
      raise "trying to delete a non-existing item #{item}"
    end
    if index != @size - 1
      swap(index, @size - 1)
      @size -= 1
      @array[@size] = nil
      percolate_up(index)
      percolate_down(index)
    else
      @size -= 1
      @array[@size] = nil
    end
  end

  private
  def percolate_down(index)
    raise "index #{index} out of bound" if index >= @size
    left = index * 2 + 1
    right = index * 2 + 2
    return index if left >= @size && right >= @size

    # +index+ may have no right child, but he must have a left child here.
    raise 'data corruption' if left >= @size

    if right < @size
      # +index+ node has two children
      if @comparator.call(@array[left][:data], @array[right][:data]) < 0
        # go left or stop
        if @comparator.call(@array[index][:data], @array[left][:data]) >= 0
          # choose left
          swap(index, left)
          return percolate_down(left)
        end
      else
        # go right or stop
        if right < @size && @comparator.call(@array[index][:data], @array[right][:data]) >= 0
          swap(index, right)
          return percolate_down(right)
        end
      end
    else
      # +index+ has only left child
      # go left or stop
      if @comparator.call(@array[index][:data], @array[left][:data]) >= 0
        # choose left
        swap(index, left)
        return percolate_down(left)
      end
    end
    index
  end
  def percolate_up(index)
    if index >= @size || index < 0
      raise "argument #{index} out of bound"
    end
    return if index == 0
    parent = (index - 1) / 2
    if @comparator.call(@array[index][:data], @array[parent][:data]) < 0
      swap(index, parent)
      percolate_up(parent)
    end
  end

  def swap(a, b)
    raise "swap two same item #{a} #{b}" if a == b
    if a >= @size || a < 0
      raise "swapping, a #{a} out of bound"
    end
    raise "swapping, b #{b} out of bound" if b >= @size || b < 0
    @array[a], @array[b] = @array[b], @array[a]
    @array[a][:index] = a
    @array[b][:index] = b
  end

end

