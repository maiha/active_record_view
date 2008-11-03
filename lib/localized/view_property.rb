class Localized::ViewProperty
  attr_reader :options, :model, :master_class, :column_name, :master_hash

  class << self
    def [](model_name, column_name)
      model = find_model(model_name)
      if model
        model.view_property(column_name)
      else
        nil
      end
    end

    private
      def find_model(name)
        @cached_models ||= {}
        case (model = @cached_models[name])
        when :missing
          return nil
        when Localized::Model
          return model
        when NilClass
          begin
            return @cached_models[name] = Localized::Model[name]
          rescue Localized::Model::ConfigurationError
            @cached_models[name] = :missing
            return nil
          end
        else
          raise "[BUG] Localized::ViewProperty is broken! (cannot find model for #{name})"
        end
      end
  end

  def initialize(model, column_name, hash = nil)
    hash ||= {}

    @blank        = true if hash.blank?
    @model        = model
    @column_name  = column_name
    @yaml_data    = hash
    @options      = hash[:options] || {}
    @master_array = []
    @master_hash  = {}
    @master_class = nil

    parse_master
    @include_blank = @master_array.first.first.to_s.empty? rescue false
  end

  def blank?
    @blank
  end

  protected
    def parse_master
      master = @yaml_data[:masters]
      @master_array = []
      @master_hash  = {}
      @master_class = nil

      case master
      when NilClass
      when String
        model = Localized::Model[master]
        @master_class = model.active_record
        @master_array = model.masters
        @master_array.each do |key, val|
          @master_hash[key] = val
        end
      when Array
        master.each do |hash|
          key, val = hash.to_a.first
          @master_array << [key, val]
          @master_hash[key] = val
        end
      else
        raise Localized::Model::ConfigurationError,
          "Cannot accept '%s' as master. It should be an Array or :belongs_to or a String(ActiveRecord class name). Check %s." % [master.class, @model.yaml_path]
      end
    end

  public
    def [](key)
      @yaml_data[key]
    end

    def masters
      @master_array
    end

    def master(value)
      @master_hash[value]
    end

    def reload_master
      parse_master
      return masters
    end

    def has_master?
      not masters.empty?
    end

    def include_blank?
      @include_blank
    end

    def has_time_format?
      self[:time_format]
    end

    def has_format?(postfix = nil)
      self["format#{postfix}".intern] || self[:format]
    end

    def has_column_type?
      self[:column_type].is_a?(Symbol)
    end

    def column_type
      (has_column_type? && self[:column_type]) || (has_master? && :master) || nil
    end

    def system_column_type
      column = klass.columns_hash[column_name.to_s]
      column ? column.type : nil
    rescue
      nil
    end

    def klass
      model.active_record
    end


  # TODO: split to property model and rendering engine
  include ActionView::Helpers::TagHelper     # for content_tag
  include ActionView::Helpers::FormHelper    # for check_box
  include ActionView::Helpers::FormTagHelper # for check_box_tag


    ######################################################################
    ### Rendering

    def human_value (value, controller = nil)
      controller &&= controller.is_a?(ActionController::Base) ? controller : controller.controller

      case column_type
      when :acts_as_bits
        aab_names = klass.send("#{column_name.to_s.singularize}_names")
        checkeds  = Hash[*aab_names.zip(value.to_s.split(//)).flatten]

        aab_masters = self.masters
        aab_masters = klass.send("#{column_name.to_s.singularize}_names_with_labels") if aab_masters.blank?

        type = :button
        case type
        when :button
          lis = aab_masters.map{|(name, title)|
            style = (checkeds[name].to_i == 1) ? "checked" : "unchecked"
            span  = content_tag(:span, title || name)
            content_tag(:li, span, :class=>style)
          }
          return content_tag(:ul, lis.join(' '), :class=>"aab")
        when :checkbox
          options = (options||{}).merge(:disabled=>"disabled")
          html = masters.map{|(name, title)|
            check = check_box_tag("aab", 1, (checkeds[name].to_i==1), options)
            label = h(title || name)
            '<span style="white-space: nowrap;">%s %s</span>' % [check, label]
          }.join(" &nbsp;&nbsp; ")
          return html
        end
      end

      if has_master?
        html = master(value)
      elsif has_time_format?
        html = [Date, Time].include?(value.class) ? value.strftime(self[:time_format]) : ''
      elsif controller && format = has_format?("_" + controller.action_name)
        html = format % ERB::Util.html_escape(value)
      elsif (column_type || system_column_type) == :text
        html = ERB::Util.html_escape(value.strip.to_s).gsub(/\r?\n/,'<BR>')
      else
        html = ERB::Util.html_escape(value)
      end
    end


    def human_edit(singular_name, view, opts = {})
      record  = opts.delete(:record) || view.instance_variable_get("@#{singular_name}")
      options = self.options.merge(opts)
      options[:class] = "#{column_name} #{options[:class]}".strip

      if time_format = has_time_format?
        value = record.send(column_name)
        if edit_format = has_format?("_edit")
          return human_edit_time_text_field_with_format(view, edit_format, value, singular_name)
        else
          return human_edit_time_with_format(view, time_format, value, singular_name)
        end
      end

      case column_type
      when :acts_as_bits
        aab_masters = self.masters
        aab_masters = klass.send("#{column_name.to_s.singularize}_names_with_labels") if aab_masters.blank?

        html = aab_masters.map{|(name, title)|
          check = view.check_box(singular_name, name, options) rescue "(#{name}?)"
          label = view.send(:h, title || name)
          label = view.send(:content_tag, :label, label, :for=>"#{singular_name}_#{name}")
          '<span style="white-space: nowrap;">%s %s</span>' % [check, label]
        }.join(" &nbsp;&nbsp; ")
      when :acts_as_tree
        value  = record.send(column_name)
        record = master_class.find(value) rescue nil
        html   = view.acts_as_tree_field(singular_name, column_name, master_class, record)
      when :checkbox, :check_box
        html = view.check_box(singular_name, column_name, options)
      when :radio, :radio_button
        separater = "&nbsp;"
        delimiter = "&nbsp;&nbsp;"
        html = masters.map{|key,val|
          [
           view.radio_button(singular_name, column_name, key, options).to_s,
           # content_tag(:label, val.to_s, :for=>"#{singular_name}_#{column_name}_#{key}")
           val.to_s
          ].join(separater)
        } * delimiter

        # add following line to your css to avoid blocked radio button in AR error
        # div.fieldWithErrors .radio-group {border:1px solid #FF0000;}
        # .radio-group div.fieldWithErrors {display : inline;}

        html = content_tag :div, html, :class=>"radio-group"
        html = content_tag :div, html, :class=>"fieldWithErrors" if record.errors.on(column_name)

      when :master
        html = view.collection_select(singular_name, column_name, masters, :first, :last, options)
      when :time
        tag  = ActionView::Helpers::InstanceTag.new(singular_name, column_name, view)
        html = tag.to_time_select_tag(options)
      when NilClass
        if system_column_type
          tag  = ActionView::Helpers::InstanceTag.new(singular_name, column_name, view, view, record)
          html = tag.to_tag(options)
        else
          if view.respond_to?(column_name)
            view.send(column_name, record)
          else
            view.text_field_tag "#{singular_name}[#{column_name}]", record[column_name]
          end
        end
      else
        tag = ActionView::Helpers::InstanceTag.new(singular_name, column_name, view, view, record)
        tag.instance_eval("def column_type; :%s; end" % self[:column_type])
        html = tag.to_tag(options)
      end

#       if format = has_format?("_" + view.controller.action_name)
#         html = format % html
#       end

      return html
    end

  protected
    def human_edit_time_with_format(view, time_format, value, singular_name)
      used = Set.new
      opts = Proc.new { |position|
        used << position
        options.merge(:prefix => singular_name, :field_name=>"#{column_name}(#{position}i)")}

      html = time_format.gsub(/%([YmdHMS])/) do
        case $1
        when 'Y'; view.select_year(value, opts.call(1))
        when 'm'; view.select_month(value, opts.call(2))
        when 'd'; view.select_day(value, opts.call(3))
        when 'H'; view.select_hour(value, opts.call(4))
        when 'M'; view.select_minute(value, opts.call(5))
        when 'S'; view.select_second(value, opts.call(6))
        end
      end

      hidden = (1...used.min).map{|i|
        name = "%s[%s]" % opts.call(i).values_at(:prefix, :field_name)
        view.hidden_field_tag(name, 1)}.join
      return hidden + html
    end

    def human_edit_time_text_field_with_format(view, time_format, value, singular_name)
      used = Set.new
      name = Proc.new { |position|
        used << position
        "%s[%s(%di)]" % [singular_name, column_name, position]}
      time = Proc.new { |time_object, method, zero|
        begin
          val = time_object.__send__(method).to_i
          val = "%02d" % val if zero
          val
        rescue
          ''
        end
      }
      opts = proc {|*args| size, klass = args
        hash = options.merge(:style=>"width:#{size}px;")
        hash.merge!(:class=>"#{hash[:class]} #{klass}") if klass
        hash
      }

      html = time_format.gsub(/%(0?)(\d*)([YmdHMS])/) do
        zero = !$1.blank?
        size = ($2.blank? ? 2 : $2).to_i*10+5
        case $3
        when 'Y'; view.text_field_tag(name.call(1), time.call(value,:year,zero),  opts.call(size))
        when 'm'; view.text_field_tag(name.call(2), time.call(value,:month,zero), opts.call(size))
        when 'd'; view.text_field_tag(name.call(3), time.call(value,:day,zero),   opts.call(size))
        when 'H'; view.text_field_tag(name.call(4), time.call(value,:hour,zero),  opts.call(size, "time-hour"))
        when 'M'; view.text_field_tag(name.call(5), time.call(value,:min,zero),   opts.call(size, "time-minute"))
        when 'S'; view.text_field_tag(name.call(6), time.call(value,:sec,zero),   opts.call(size))
        end
      end

      hidden = (1...used.min).map{|i| view.hidden_field_tag(name.call(i), 1)}.join
      return hidden + html
    end

    def configuration_error(message)
      raise Localized::Model::ConfigurationError, "%s (check 'property_%s' in %s)" %
        [message, column_name, model.yaml_path]
    end
end



