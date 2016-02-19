class Warehouse
  attr_accessor :index, :x, :y, :products

  def initialize(index, products_count)
    @products = Array.new(products_count)
    @index = index
  end

  def parse(file)
    read_coords(file.readline)
    read_items(file.readline)
  end

  def read_coords(line)
    @x, @y = line.split(' ').map(&:to_i)
  end

  def read_items(line)
    @products = line.split(' ').map(&:to_i)
  end

  def in_storage?(product, count)
    return @products[product] - count >= 0
  end

  def pull(product, count)
    @products[product] -= count
  end

  def push(product, count)
    @products[product] += count
  end

  def get_distance(item)
    abs_x = ((@x - item.x) * (@x - item.x)).abs
    abs_y = ((@y - item.y) * (@y - item.y)).abs
    Math.sqrt(abs_x + abs_y).ceil
  end  
end
