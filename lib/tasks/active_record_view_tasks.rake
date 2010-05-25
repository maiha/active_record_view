
def arv_file(name)
  path = File.dirname(__FILE__) + "/../arv/#{name}"
  File.read(path)
end

def enved_model
  name = ENV["MODEL"].to_s
  arv_fatal if name.blank?
  returning name.constantize do |klass|
    unless klass.ancestors.include?(ActiveRecord::Base)
      arv_fatal("%s is not a subclass of ActiveRecord::Base" % klass)
    end
  end
end

def arv_fatal(message = nil)
  puts message unless message.to_s.empty?
  puts "specify AR model class name by 'MODEL' env"
  puts "  ex) rake arv:create:view MODEL=User"
  exit
end

namespace "arv" do
  task "create:view" => :environment do
    require 'erb'
    klass = enved_model
    src = arv_file("property.erb")
    erb = ERB.new(src, nil, '-')
    yml = erb.result(binding)

    dst = Pathname("%s/%s.yml" % [Localized::Model.yaml_path, klass.table_name]).cleanpath
    dst.parent.mkpath
    puts "writing YAML data to %s" % dst
    File.open(dst, "w+") {|f| f.print yml}
  end
end
