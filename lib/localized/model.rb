class Localized::Model
  attr_reader :yaml_path, :active_record
  delegate :logger, :to=>"ActiveRecord::Base"
  cattr_accessor :yaml_path
  if defined?(RAILS_ROOT)
    self.yaml_path = File.join(RAILS_ROOT, "db/localized")
  end

  class ConfigurationError < ActionView::ActionViewError; end
  class << self
    def [](model_name)
      klass = active_record_class_for(model_name)
      @localized_models ||= {}
      @localized_models[klass.table_name] ||= new(klass)
    end

    def active_record_class_for(klass)
      case klass
      when Class
        # nop
      when ActiveRecord::Base
        klass = klass.class
      else
        klass = klass.to_s.classify.constantize
      end

      klass.ancestors.include?(ActiveRecord::Base) or
        raise ConfigurationError, "#{name}[] expects ActiveRecord class, but got #{klass.name}"

      return klass
    end

    def human_value(record, column_name)
      self[record.class].view_property(column_name).human_value(record[column_name])
    end

    def masters(model_name, column_name)
      self[model_name].view_property(column_name).masters
    end
  end

  def initialize(active_record)
    @active_record   = active_record
    @table_name      = @active_record.table_name
    @view_properties = {}
    @yaml = YAML::load_file(absolute_yaml_path)
    logger.debug("Loaded localized setting from '#{absolute_yaml_path}'")
  rescue Errno::ENOENT
    raise ConfigurationError, "Cannot read YAML data from #{absolute_yaml_path}.\nRun 'rake arv:create:view %s'" % @active_record
  rescue ArgumentError => err
    logger.debug("Localize Error: YAML #{err} in #{yaml_path}")
    @load_error = true
  end

  def [] (group_name, attr_name = nil)
    return nil if load_error?
    localized_name = @yaml[group_name.to_s]
    localized_name = localized_name[attr_name] if attr_name
    return localized_name
  rescue => err
    logger.debug("Localize Error: for (%s,%s). %s" % [group_name, attr_name, err])
    return nil
  end

  def instance_name
    self[:names][:instance]
  end

  def masters
    pkey    = active_record.primary_key
    options = active_record.columns_hash[instance_name.to_s] && {:select=>"#{pkey},#{instance_name}"} || {}
    active_record.find(:all, options.merge(:order=>pkey)).collect{|r| [r[pkey], localize_instance(r)]}
  end

  def localize_instance (record)
    name = instance_name
    case name
    when NilClass ; return nil
    when Symbol ; return record.send(name)
    when String ; return name.gsub('%d', record.id.to_s)
    else
      raise TypeError, "got %s, expected Symbol or String. Check '%s'" % [name.class, yaml_path]
    end
  end

  def load_error?
    @load_error
  end

  def view_property(column_name)
    @view_properties[column_name] ||= Localized::ViewProperty.new(self, column_name, self["property_#{column_name}"])
  end

  private
    def absolute_yaml_path
      @absolute_yaml_path ||= (Pathname(self.class.yaml_path) + yaml_path).cleanpath
    end

    def yaml_path
      "#{@table_name}.yml"
    end

end
