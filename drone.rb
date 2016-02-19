class Drone
  attr_accessor :delivery, :index, :products, :commands, :turns, :x, :y, :current_load, :out_of_turns

  def initialize(index, delivery)
    @index = index
    @commands = Array.new
    @turns = 0
    @x = 0
    @y = 0
    @current_load = 0
    @delivery = delivery
    @products = Array.new
    @out_of_turns = false
  end

  def load_and_deliver(order, warehouse)
    return false unless load_at_max(order, warehouse)
    return false unless deliver_all(order)
    return true
  end

  def get_max_load(order, warehouse)
    max_load = @current_load
    order.products.each do |product|
      if  warehouse.in_storage?(product, 1) &&
          (max_load + delivery.products[product] <= delivery.maxpayload)
        max_load += delivery.products[product]
      end
    end
    max_load - @current_load
  end

  def can_load_all?(order, warehouse)
    max_load = @current_load
    order.products.each do |product|
      if  warehouse.in_storage?(product, 1) &&
          (max_load + delivery.products[product] <= delivery.maxpayload)
        max_load += delivery.products[product]
      else
        return false
      end
    end
    return true
  end

  # def load_at_max(order, warehouse)
  #   #puts "loading from warehouse: #{warehouse.index} - #{warehouse.products}"
  #   order.products.each do |product|
  #     if has_turns?(warehouse)
  #       load(product, warehouse) if warehouse.in_storage?(product, 1) && can_load?(product, 1)
  #     else
  #       @out_of_turns = true
  #       return false
  #     end
  #   end
  #   return true
  # end

  KnapsackItem = Struct.new(:weight, :value)

  def load_at_max(order, warehouse)
    potential_items = Array.new

    order.products.each do |product|
      next unless warehouse.in_storage?(product, 1)
      potential_items << KnapsackItem[@delivery.products[product], product]
    end

    knapsack_capacity = @delivery.maxpayload - @current_load

    maxval, solutions = potential_items.power_set.group_by {|subset|
      weight = subset.inject(0) {|w, elem| w + elem.weight}
      weight>knapsack_capacity ? 0 : subset.inject(0){|v, elem| v + elem.value}
    }.max

    solutions.each do |set|
      items = []
      set.each do |elem|
        if has_turns?(warehouse)
          load(elem.value, warehouse) if can_load?(elem.value, 1) && warehouse.in_storage?(elem.value, 1)
        else
          @out_of_turns = true
          return false
        end
      end
    end
    return true
  end

  def deliver_all(order)
    #puts "delivering order: #{order.index}"
    order_products = order.products.dup
    order_products.each do |product|
      if has_turns?(order)
        deliver(product, order) if contains?(product)
      else
        @out_of_turns = true
        return false
      end
    end
    return true
  end

  def load(product, warehouse)
    goto(warehouse)
    @products << product
    @current_load += delivery.products[product] * 1
    warehouse.pull(product, 1)
    command('L', warehouse.index, product, 1)
  end

  def deliver(product, order)
    goto(order)
    @products.slice!(@products.index(product))
    @current_load -= delivery.products[product] * 1
    order.mark_as_delivered(product)
    command('D', order.index, product, 1, order.is_completed? ? 'completed' : '' )
  end

  def command(cmd, data, product, count, extra = '')
    command = "#{index} #{cmd} #{data} #{product} #{count}"
    #puts  "#{command} #{extra}"
    commands << command
  end

  def goto(destination)
    @turns += get_turns(destination)
    @x = destination.x
    @y = destination.y
  end

  def can_load?(product, count)
    return @current_load + (delivery.products[product] * count) <= delivery.maxpayload
  end

  def contains?(product)
    @products.include?(product)
  end

  def wait(turns)
    commands << "#{index} W #{turns}"
  end

  def has_turns?(destination)
    necessary_turns = get_turns(destination)
    @turns + necessary_turns < delivery.turns
  end

  def get_turns(item)
    get_distance(item) + 1.0
  end

  def get_distance(item)
    abs_x = ((@x - item.x) * (@x - item.x)).abs
    abs_y = ((@y - item.y) * (@y - item.y)).abs
    Math.sqrt(abs_x + abs_y).ceil
  end

  def get_nearest_target(items)
    best_item = nil
    best_distance = nil

    items.each do |item|
      distance = get_distance(item)
      if best_distance.nil? || distance < best_distance
        best_distance = distance
        best_item = item
      end
    end

    best_item
  end
end

class Array
  # do something for each element of the array's power set
  def power_set
    yield [] if block_given?
    self.inject([[]]) do |ps, elem|
      ps.each_with_object([]) do |i,r|
        r << i
        new_subset = i + [elem]
        yield new_subset if block_given?
        r << new_subset
      end
    end
  end
end
