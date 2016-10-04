require "#{ARGV[0]}"
class MethodSender
  def send(object, method)
    init_args = object.instance_method(:initialize).arity
    init_args > 0 ? init_args = Array.new(init_args) : init_args = []
    init_args.empty? ? instance = object.send(:new) : instance = object.send(:new, init_args)
    num_args = object.instance_method(method).arity
    num_args > 0 ? args = Array.new(num_args) : args = []
    args.empty? ? instance.send(method) : instance.send(method, args)
  end
end

class Node
  attr_reader :class, :public_methods, :attributes, :private_methods

  def initialize
    @class = nil
    @public_methods = []
    @private_methods = []
    @attributes = []
    @sender = MethodSender.new
  end

  def analyse(classObject)
    @class = classObject
    update_attributes
    update_public_methods
    update_private_methods
  end

  private

  def update_attributes
    @attributes = @sender.send(@class,:instance_variables)
  end

  def update_public_methods
    @public_methods = @sender.send(@class,:public_methods) - Object.new.public_methods
  end

  def update_private_methods
    @private_methods = @sender.send(@class,:private_methods) - Object.new.private_methods
  end
end

class NodeMapper
  attr_reader :vertices

  def initialize(nodes)
    @nodes = nodes
    @vertices = []
  end

  def find_vertices
    @nodes.each do |node|
      node.public_methods.each do |method|
        sender = MethodSender.new
        set_trace_func proc { |event, file, line, id, binding, classname|
          @vertices << [node.class, method, event, id, classname]
        }
          sender.send(node.class, method)
        set_trace_func(nil)
      end
    end
    @vertices = @vertices.select{|node, method, event, id, classname| event == 'call' && node !=classname && classname != MethodSender}
    @vertices = @vertices.map{|node, method, event, id, classname| [node, method, id, classname]}
  end
end

class DomainModel

  attr_reader :nodes, :classes, :vertices

  def initialize(file)
    file = File.open(ARGV[0])
      @classes = file.read.scan(/class (\w+)/).flatten
    file.close
    @nodes = []
    @vertices = []
    @objects = @classes.map do |className|
      Object.const_get("#{className}")
    end
    self.get_nodes
    self.get_vertices
  end

  def get_nodes
    @objects.each do |object|
      node = Node.new
      node.analyse(object)
      @nodes << node
    end
  end

  def get_vertices
    @vertices = NodeMapper.new(@nodes).find_vertices
  end
end

class PrettyPrinter

  def print(domain_model)
    puts '========================================================'
    puts 'CLASSES:'
    puts '--------------------------------------------------------'
    domain_model.nodes.each do |node|
      puts node.class
      puts "  - Attributes:"
      node.attributes.each do |attribute|
        puts "    * " + attribute.to_s
      end
      puts "  - Public Methods:"
      node.public_methods.each do |publicmethod|
        puts "    * " + publicmethod.to_s
      end
      puts "  - Private Methods:"
      node.private_methods.each do |privatemethod|
        puts "    * " + privatemethod.to_s
      end
      puts '--------------------------------------------------------'
    end
    puts 'DEPENDENCIES:'
    puts '--------------------------------------------------------'
    domain_model.vertices.each do |callClass, parentMethod, calledMethod, receipient|
      puts "  - The method call #{callClass}.#{parentMethod} calls the method ##{calledMethod} on the #{receipient} class."
    end
    puts '========================================================'
  end
end

PrettyPrinter.new.print(DomainModel.new(ARGV[0]))
