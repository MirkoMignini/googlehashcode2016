require_relative './warehouse'
require_relative './order'
require_relative './drone'
require 'ai4r'

class Delivery
  attr_accessor :rows, :columns, :drones, :turns, :maxpayload, :max_distance
  attr_accessor :warehouses, :products, :orders

  def read_file(file_name)
    File.open(file_name, 'r') do |file|
      read_header(file.readline)
      read_product_types(file.readline)
      read_products_weigh(file.readline)

      read_warehouses(file.readline)
      (@warehouses.count).times do |i|
        @warehouses[i] = Warehouse.new(i, @products.count)
        @warehouses[i].parse(file)
      end

      read_orders(file.readline)
      (orders.count).times do |i|
        @orders[i] = Order.new(i, self)
        @orders[i].parse(file)
      end

      @drones.each do |drone|
        drone.x = @warehouses[0].x
        drone.y = @warehouses[0].y
      end

      #busy_day
      # @turns = 35100
      # @max_distance = 100
      # @orders.sort! { |x, y| x.products.count <=> y.products.count }

      #mother
      # @turns = 27500
      # @max_distance = 25
      # @orders.sort! { |x, y| x.get_distance(@warehouses[0]) <=> y.get_distance(@warehouses[0]) }

      #redundancy
      #@turns = 12500
      @max_distance = 40
      #@orders.sort! { |x, y| x.weight <=> y.weight }
      #@orders.sort! { |x, y| x.products.count <=> y.products.count }
      # @orders.sort! do |x, y|
      #   wx = get_best_warehouse(x)
      #   wy = get_best_warehouse(y)
      #   x.get_distance(wx) <=> y.get_distance(wy)
      # end

      #puts 'All parsed' if (file.eof?)
    end
  end

  def debug_warehouses
    @warehouses.each do |warehouse|
      puts "warehouse: #{warehouse.index} - #{warehouse.products}"
    end
  end

  def debug_drones
    avg = 0
    @drones.each do |drone|
      puts "drone #{drone.index} - turns: #{drone.turns} - out: #{drone.out_of_turns}"
      avg += drone.turns
    end
    puts "Avg turns #{avg / @drones.count}"
  end

  def process
    index = 0
    loop do
      index += 1

      pending_orders = Array.new
      @orders.each do |order|
        next if order.is_completed?
        pending_orders << order
      end

      break if pending_orders.count == 0

      available_drones = @drones.select{ |drone| drone.out_of_turns == false }
      available_drones.sort! { |x, y| x.turns <=> y.turns }

      if available_drones.count == 0
        puts 'Out of drones!'
        return
      end

      drone = available_drones[0]
      warehouse = drone.get_nearest_target(@warehouses)
      orders = Array.new

      order = nil
      pending_orders.sort! do |x, y|
        x.products.count <=> y.products.count
        #x.get_distance(warehouse) <=> y.get_distance(warehouse)
      end
      pending_orders.each do |pending_order|
        best_warehouse = get_best_warehouse(pending_order)
        if best_warehouse == warehouse
          order = pending_order
          break
        end
      end

      if order.nil?
        puts '------'
        order = pending_orders[0]
        warehouse = get_best_warehouse(order)
      end

      orders = Array.new
      orders << order

      #warehouse = get_best_warehouse(order)
      #drone = get_best_drone(warehouse)

      puts "pendings: #{pending_orders.count} order: #{order.index} w: #{order.weight} -- drone: #{drone.index} turn: #{drone.turns} -- prods: #{order.products}"

      drone.load_at_max(order, warehouse)
      loop do
        joinable_order = get_joinable_order(drone, warehouse, orders)
        break if joinable_order.nil?
        orders << joinable_order
        drone.load_at_max(joinable_order, warehouse)
      end

      if orders.count > 3
        data = Array.new(orders.count)
        orders.each_with_index do |order_x, index_x|
          data[index_x] = Array.new(orders.count)
          orders.each_with_index do |order_y, index_y|
            data[index_x][index_y] = order_x.get_distance(order_y)
          end
        end
        Ai4r::GeneticAlgorithm::Chromosome.set_cost_matrix(data)
        3.times do
          c = Ai4r::GeneticAlgorithm::Chromosome.seed
        end
        search = Ai4r::GeneticAlgorithm::GeneticSearch.new(800, 100)
        result = search.run
        result.data.each do |index|
          drone.deliver_all(orders[index])
        end
      else
        delivers = orders.dup
        while delivers.count > 0
          deliverable_order = drone.get_nearest_target(delivers)
          delivers.delete(deliverable_order)
          drone.deliver_all(deliverable_order)
        end
      end

    end

    debug_drones
  end

  def process_old
    @orders.each do |order|
      100.times do |t|
        break if order.is_completed?

        orders = Array.new
        orders << order

        warehouse = get_best_warehouse(order)
        drone = get_best_drone(warehouse)

        if drone.nil?
          puts 'Out of drones!'
          return
        end

        puts "order: #{order.index}/#{t} w: #{order.weight} -- drone: #{drone.index} turn: #{drone.turns} -- prods: #{order.products}"

        drone.load_at_max(order, warehouse)

        loop do
          joinable_order = get_joinable_order(drone, warehouse, orders)
          break if joinable_order.nil?
          orders << joinable_order
          drone.load_at_max(joinable_order, warehouse)
        end

        delivers = orders.dup
        while delivers.count > 0
          deliverable_order = drone.get_nearest_target(delivers)
          delivers.delete(deliverable_order)
          drone.deliver_all(deliverable_order)
        end
      end
      #return
    end

    debug_drones
  end

  # def orders_completed?(orders)
  #   orders.each { |order| return false if order.is_completed? == false }
  #   return true
  # end
  #
  # def all_orders_completed?
  #   @orders.each { |order| return false if order.is_completed? == false }
  #   return true
  # end

  attr_accessor :best_orders_count

  def get_joinable_order(drone, warehouse, orders)
    max_distance = @max_distance
    best_orders = Array.new

    @orders.each do |order|
      next if order.is_completed?
      next if orders.map(&:index).include?(order.index)
      next if orders[0].get_distance(order) > max_distance
      next unless drone.can_load_all?(order, warehouse)
      best_orders << order
    end

    best_order = nil

    if best_orders.count > 0
      @best_orders_count = 0 if @best_orders_count.nil?
      @best_orders_count += 1
      best_distance = nil
      best_orders.each do |order|
        distance = orders[0].get_distance(order)
        if best_distance.nil? || distance < best_distance
          best_distance = distance
          best_order = order
        end
      end
    else
      best_distance = nil
      @orders.each do |order|
        next if order.is_completed?
        next if orders.map(&:index).include?(order.index)
        next if drone.get_max_load(order, warehouse) == 0

        distance = orders[0].get_distance(order)
        next if distance > max_distance

        if best_distance.nil? || distance < best_distance
          best_distance = distance
          best_order = order
        end
      end
    end

    best_order
  end

  # def get_joinable_order(drone, warehouse, orders)
  #   best_order = nil
  #   best_distance = nil
  #
  #   max_load = @maxpayload - drone.current_load
  #
  #   @orders.each do |order|
  #     next if order.is_completed?
  #     next if orders.map(&:index).include?(order.index)
  #     next if drone.get_max_load(order, warehouse) == 0
  #
  #     distance = orders[0].get_distance(order)
  #     next if distance > 20#100#60#40
  #
  #     if best_distance.nil? || distance < best_distance
  #       best_distance = distance
  #       best_order = order
  #     end
  #   end
  #
  #   best_order
  # end

  def get_best_warehouse(order)
    results = Array.new(@warehouses.count).fill(0)

    @warehouses.each_with_index do |warehouse, index|
      warehouse_products = warehouse.products.clone
      order.products.each do |product|
        if warehouse_products[product] > 0
          results[index] += 1 #@products[product]
          warehouse_products[product] -= 1
        end
      end
    end

    best_warehouse = nil
    best_distance = nil
    @warehouses.each do |warehouse|
      next if results[warehouse.index] != results.max
      distance = order.get_distance(warehouse)
      if best_distance.nil? || distance < best_distance
        best_distance = distance
        best_warehouse = warehouse
      end
    end

    best_warehouse
  end

  def get_best_drone(warehouse)
    best_drone = nil
    best_distance = nil

    @drones.each do |drone|
      next if drone.out_of_turns
      distance = drone.get_distance(warehouse)
      if best_distance.nil? || distance < best_distance
        best_distance = distance
        best_drone = drone
      end
    end

    best_drone
  end

  def read_header(line)
    @rows, @columns, @drones, @turns, @maxpayload = line.split(' ').map(&:to_i)
    @drones = Array.new(@drones){ |i| Drone.new(i, self) }
  end

  def read_product_types(line)
    @products = Array.new(line.to_i)
  end

  def read_products_weigh(line)
    @products = line.split(' ').map(&:to_i)
  end

  def read_warehouses(line)
    @warehouses = Array.new(line.to_i)
  end

  def read_orders(line)
    @orders = Array.new(line.to_i)
  end

  def write_file(file_name)
    File.open(file_name, 'w') do |file|
      lines = @drones.map(&:commands).map(&:count).reduce(0, :+)
      file.write("#{lines}\n")
      @drones.each do |drone|
        drone.commands.each do |command|
          file.write("#{command}\n")
        end
      end
    end
  end
end

delivery = Delivery.new
delivery.read_file(ARGV[0])
delivery.process
delivery.write_file(ARGV[0].gsub('.in', '.out'))
