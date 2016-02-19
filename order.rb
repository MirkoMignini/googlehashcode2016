class Order
  attr_accessor :index, :x, :y, :products, :weight, :delivery

  def initialize(index, delivery)
    @index = index
    @delivery = delivery
  end

  def parse(file)
    read_coords(file.readline)
    read_products_count(file.readline)
    read_products(file.readline)
  end

  def read_coords(line)
    @x, @y = line.split(' ').map(&:to_i)
  end

  def read_products_count(line)
    @products = Array.new(line.to_i)
  end

  def read_products(line)
    @products = line.split(' ').map(&:to_i)
    @products.sort!
    calc_weight
  end

  def is_completed?
    @products.count == 0
  end

  def mark_as_delivered(product)
    @products.slice!(@products.index(product))
    calc_weight
  end

  def get_distance(item)
    abs_x = ((@x - item.x) * (@x - item.x)).abs
    abs_y = ((@y - item.y) * (@y - item.y)).abs
    Math.sqrt(abs_x + abs_y).ceil
  end

  def calc_weight
    @weight = @products.map { |index| delivery.products[index] }.reduce(:+)
  end
end
