module ActiveRecordView
  module Engines
    extend RecordIdentifier

    ######################################################################
    ### Abstract Engine

    class Base
      include RecordIdentifier

      def initialize(*args)
        @method, @klass, @column, @view = args
      end

      def value(record, column = @column, view = @view)
        record.__send__(column)
      end

      def show(record, column = @column, view = @view)
        value(record, column, view)
      end

      def edit(record, column = @column, view = @view, record_name = nil)
        record_name ||= singular_class_name(record.class)
        tag_id   = "#{record_name}_#{column}"
        tag_name = "#{record_name}[#{column}]"
        view.text_field_tag tag_name, value(record, column, view), :name=>tag_name
      end
    end

    ######################################################################
    ### Concreate Engines

    # helper methods should have first priority
    class Helper < Base
      def show(record, column = @column, view = @view)
        view.__send__(@method, record)
      end

      def edit(record, column = @column, view = @view, record_name = nil)
        view.__send__(@method, record)
      end
    end

    # then we search view properties
    class Property < Base
      def show(record, column = @column, view = @view)
        @method.human_value(super, view)
      end

      def edit(record, column = @column, view = @view, record_name = nil)
        record_name ||= singular_class_name(record.class)
        @method.human_edit(record_name, view, :record=>record)
      end
    end

    # and then we try ducktyping by respond_to?
    class DuckType < Base
    end

    # when no engines are found, we try to call record[key] as a last-effort
    class Missing < Base
      def value(record, column = @column, view = @view)
        record[column]
      end
    end
  end
end
