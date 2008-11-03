module ActiveRecordView::Helper
  include ActiveRecordView::RecordIdentifier
  include ActiveRecordView::WriteException
  include ActiveRecordView::DefaultActions
  include ActiveRecordView::RenderArv

  def collection_tr_for(*args)
    options = args.optionize :records, :fields
    return nil if options[:records].blank?

    if options[:fields].blank?
      record = options[:records].first
      record.is_a?(ActiveRecord::Base) or
        raise TypeError, "expect ActiveRecord, but got #{record.class}"
      options[:fields] = record.class.content_columns.map(&:name)
    end

    options[:records].map do |record|
      style = list_row_class(record) if respond_to? :list_row_class
      content_tag :tr,
      options[:fields].map{|name|
        html = active_record_value(record, name, :singular_name => options[:singular_name])
        content_tag :td, html, :class=>name
      }.join,
      :class => [style, dom_class(record), options[:class] || options[:singular_name]].compact.join(' '),
      :id    => dom_id(record, options[:prefix])
    end.join
  end

  def collection_tbody_for(*args)
    html = collection_tr_for(*args)
    if html.blank?
      return nil
    else
      content_tag(:tbody, html)
    end
  end

  ######################################################################
  ### ActiveRecord value
  def active_record_value(record_or_name, format, options = {})
    record = active_record_for(record_or_name)
    engine = find_active_record_view_engine(record.class, format)
    engine.show(record, format, self)
  rescue NameError => err
    write_exception(err)
    record[format]
  rescue Exception => err
    active_record_error(err, record_or_name, format, options)
  end

  def active_record_form(record_or_name, format, options = {})
    record_name = active_record_name_for(record_or_name)
    record = options[:record] || active_record_for(record_or_name)
    engine = find_active_record_view_engine(record.class, format, "edit_")
    engine.edit(record, format, self, record_name)
  rescue Exception => err
    active_record_error(err, record_or_name, format, options)
  end

  def find_active_record_view_engine(klass, column, prefix = nil)
    caching_key = [klass, column, prefix]
    @cached_arv_engines ||= {}
    @cached_arv_engines[caching_key] ||= active_record_view_engine_for(klass, column, prefix)
  end

  def active_record_error(err, record_or_name, format, options)
    write_exception(err)
    '???'
  end

  private
    def active_record_for(record_or_name, strict = false)
      record =
        case record_or_name
        when String, Symbol
          instance_variable_get("@#{record_or_name}")
        else
          record_or_name
        end
      if strict and !record.is_a?(ActiveRecord::Base)
        raise TypeError, "expect ActiveRecord, but got #{record.class} by #{record_or_name.inspect}"
      end
      return record
    end

    ######################################################################
    ### Engine mapper

    def active_record_view_engine_for(klass, column, prefix = nil)
      ActiveRecord::Base.logger.debug "active_record_view: searching renderer for (%s, %s)" % [klass, column]
      column = column.to_s.intern
      active_record_view_engine_for_active_record(klass, column, self, prefix) or
        active_record_view_engine_for_classed_helper(klass, column, self) or
        active_record_view_engine_for_helper(klass, column, self) or
        active_record_view_engine_for_ducktype(klass, column, self) or
        active_record_view_engine_for_missing(klass, column, self) or
        raise TypeError, "no engines found for #{klass}"
    end

    def active_record_view_engine_for_classed_helper(klass, column, view)
      method = "%s_%s" % [active_record_name_for(klass), column]
      view.respond_to?(method) and
        ActiveRecordView::Engines::Helper.new(method, klass, column, view)
    end

    def active_record_view_engine_for_helper(klass, column, view)
      view.respond_to?(column) and
        ActiveRecordView::Engines::Helper.new(column, klass, column, view)
    end

    def active_record_view_engine_for_ducktype(klass, column, view)
      klass.new.respond_to?(column) and
        ActiveRecordView::Engines::DuckType.new(column, klass, column, view)
    rescue ArgumentError
      klass.instance_methods.include?(column.to_s) and
        ActiveRecordView::Engines::DuckType.new(column, klass, column, view)
    end

    def active_record_view_engine_for_missing(klass, column, view)
      klass.instance_methods.include?("[]") and
        ActiveRecordView::Engines::Missing.new(column, klass, column, view)
    end

    def active_record_view_engine_for_active_record(klass, column, view, prefix)
      index = klass.ancestors.index(ActiveRecord::Base) or return nil
      ancestors = [klass] + klass.ancestors[0...index]
      checked_methods = {}
      ancestors.each do |k|
        helper_method = ("%s%s_%s" % [prefix, active_record_name_for(k), column]).intern
        next if checked_methods[helper_method]
        checked_methods[helper_method] = true

        # first, check helper methods
        exist = respond_to?(helper_method)
        ActiveRecord::Base.logger.debug "  helper method '#{helper_method}' ... %s" % (exist ? "yes" : "no")
        return ActiveRecordView::Engines::Helper.new(helper_method, klass, column, view) if exist

        # second, check view property if not STI
        next unless k.is_a?(Class)
        next unless k.descends_from_active_record?

        property = Localized::ViewProperty[k, column]
        if property and !property.blank?
          ActiveRecord::Base.logger.debug "  ViewProperty[%s, %s] ... yes" % [k, column]
          return ActiveRecordView::Engines::Property.new(property, klass, column, view)
        end
      end
      return nil
    end

end
