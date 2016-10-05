Dir["#{ARGV[0]}/*.rb"].each {|file| require file }

class Spy
  attr_reader :calls
  def initialize
    @calls = []
  end
  def method_missing(method_sym)
    @calls << method_sym
    return  self
  end
end

class MethodSender
  attr_reader :classSpy, :instanceSpy
  def initialize
    @classSpy = Spy.new
    @instanceSpy = Spy.new
  end

  def send(object, method)
      init_args = object.instance_method(:initialize).arity
      init_args > 0 ? init_args = Array.new(init_args, @classSpy) : init_args = []
      init_args.empty? ? instance = object.send(:new) : instance = object.send(:new, init_args)
      num_args = object.instance_method(method).arity
      num_args > 0 ? args = Array.new(num_args, @instanceSpy) : args = []
      args.empty? ? instance.send(method) : instance.send(method, *args)
  end
end

class Node
  attr_reader :classname, :public_methods, :attributes, :private_methods

  def initialize
    @classname = nil
    @public_methods = []
    @private_methods = []
    @attributes = []
    @sender = MethodSender.new
  end

  def analyse(classObject)
    @classname = classObject
    update_attributes
    update_public_methods
    update_private_methods
  end

  private

  def update_attributes
    @attributes = @sender.send(@classname, :instance_variables)
  end

  def update_public_methods
    @public_methods = @sender.send(@classname, :public_methods) - Object.new.public_methods
  end

  def update_private_methods
    @private_methods = @sender.send(@classname, :private_methods) - Object.new.private_methods
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
          @vertices << [node.classname, method, event, file, line, id, classname]
        }
          sender.send(node.classname, method)
        set_trace_func(nil)

        sender.instanceSpy.calls.each do |call|
          target = @nodes.select{|node| node.public_methods.include? call}.pop
          @vertices << [node.classname, method, "call", "file", "unknown", call, target.classname]
        end
      end
    end
    classes = @nodes.map(&:classname).push("Injected")
    @vertices = @vertices.select{|node, method, event, file, line, id, classname|  node !=classname && (classes.include? classname)}
    @vertices = @vertices.map{|node, method, event, file, line, id, classname| [node, method, id, classname]}.uniq
  end
end

class FileMerger
  def self.concatenate(directory)
    dirTree = File.absolute_path(directory)
    File.open('merged.txt','a') do |mergedFile|
      topDir = File.absolute_path(directory)
      filesInDir = Dir["#{topDir}/**/**/*.*"]
      filesInDir.each do |file|
        unless File.basename(file) =~ /jpg|png|gif|modernizr|fancybox|jquery/
          relativePath = File.absolute_path(file).gsub("#{dirTree}","..")
          puts "processing: #{relativePath}"
          mergedFile << "\n\n=========================================================\n"
          mergedFile << "#{relativePath}\n"
          mergedFile << "=========================================================\n\n"
          text = File.open(file, 'r').read
          text.each_line do |line|
            mergedFile << line
          end
        end
      end
    end
  end
end

class DomainModel

  attr_reader :nodes, :classes, :vertices

  def initialize(directory)
    FileMerger.concatenate(directory)
    file = File.open('./merged.txt')
      @classes = file.read.scan(/class (\w+)/).flatten
      p @classes
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
      puts node.classname
      puts "  - Attributes:"
      node.attributes.each do |attribute|
        puts "    * " + attribute.to_s
      end
      puts " "
      puts "  - Public Methods:"
      node.public_methods.each do |publicmethod|
        puts "    * " + publicmethod.to_s
      end
      puts " "
      puts "  - Private Methods:"
      node.private_methods.each do |privatemethod|
        puts "    * " + privatemethod.to_s
      end
      puts " "
      puts '--------------------------------------------------------'
    end
    puts 'DEPENDENCIES:'
    puts '--------------------------------------------------------'
    domain_model.vertices.each do |callClass, parentMethod, calledMethod, receipient|
      puts "  - The method call #{callClass}.#{parentMethod} calls the method ##{calledMethod} on the #{receipient} class."
      puts " "
    end
    puts '========================================================'
  end
end

PrettyPrinter.new.print(DomainModel.new(ARGV[0]))
File.delete('./merged.txt')
