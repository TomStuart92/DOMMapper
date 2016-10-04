require "#{ARGV[0]}"



class Node
  attr_reader :class, :public_methods

  def initialize
    @class = nil
    @public_methods = []
    @private_methods = []
    @attributes = []
  end

  def analyse(classObject)
    @class = classObject
    update_attributes
    update_public_methods
    update_private_methods
  end

  private

  def update_attributes
    @attributes = @class.new.instance_variables
  end

  def update_public_methods
    @public_methods = @class.new.public_methods - Object.new.public_methods
  end

  def update_private_methods
    @private_methods = @class.new.private_methods - Object.new.private_methods
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
        set_trace_func proc { |event, file, line, id, binding, classname|
          @vertices << [node.class, method, event, id, classname]
        }
          p method.parameters
          node.class.new.send(method)
        set_trace_func(nil)
      end
    end
    @vertices = @vertices.select{|node, method, event, id, classname| event == 'call'}
  end
end

file = File.open(ARGV[0])
  classes = file.read.scan(/class (\w+)/).flatten
file.close

objects = classes.map do |className|
  Object.const_get("#{className}")
end

@nodes = []

objects.each do |object|
  node = Node.new
  node.analyse(object)
  @nodes << node
end

nm = NodeMapper.new(@nodes)
nm.find_vertices
nm.vertices
