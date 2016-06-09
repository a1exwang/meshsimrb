require 'rspec'
require_relative '../deletable_heap'

RSpec.describe DeletableHeap do
  it 'can do heap sort' do
    heap = DeletableHeap.new { |x, y|  x <=> y }
    heap.push(4)
    heap.push(2)
    heap.push(3)
    heap.push(1)

    result = []
    heap.size.times { result << heap.pop }
    expect(result).to eq([1,2,3,4])
  end
  it 'can do heap sort with duplicate elements' do
    heap = DeletableHeap.new { |x, y|  x <=> y }
    heap.push(4)
    heap.push(4)
    heap.push(3)
    heap.push(2)

    result = []
    heap.size.times { result << heap.pop }
    expect(result).to eq([2,3,4,4])
  end
  it 'can push item and return index' do
    heap = DeletableHeap.new { |x, y|  x <=> y }
    10.times do |i|
      expect(heap.push(i)[:index]).to eq(i)
    end
  end
  it 'can delete item' do
    heap = DeletableHeap.new { |x, y|  x <=> y }
    heap.push(1)
    heap.push(4)
    item = heap.push(3)
    heap.push(2)

    heap.delete(item)

    result = []
    heap.size.times { result << heap.pop }
    expect(result).to eq([1,2,4])
  end

  it 'has a valid index for all items' do
    heap = DeletableHeap.new { |x, y|  x <=> y }
    start = 100
    item = heap.push(start)
    expect(item[:index]).to eq(0)
    heap.push(start - 1)
    expect(item[:index]).to eq(1)
  end

  it 'should hash swap valid' do

    item1 = { index: 1, data: {} }
    item1[:data][:ref] = item1
    item2 = { index: 2, data: {} }
    item2[:data][:ref] = item2

    hash = {
        1 => item1,
        2 => item2
    }

    hash[1], hash[2] = hash[2], hash[1]
    expect(hash[1][:index]).to eq(2)
    expect(hash[1][:data][:ref].__id__).to eq(item2.__id__)
  end

end