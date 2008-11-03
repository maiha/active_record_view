module ActiveRecordView
  module RenderArv
    def render(*args, &block)
      options = args.first
      if options.is_a?(Hash) and options[:arv]
        arv = options.delete(:arv)
        render_arv(arv, options)
      else
        super
      end
    end

    def render_arv(arv, options = {})
      path, arv_name = partial_pieces(arv.to_s)
      root  = Pathname(RAILS_ROOT).cleanpath.to_s + "/"
      file  = "app/views/%s/%s.arv" % [path, arv_name]
      rhtml = arv_erb_code(File.read(root + file), arv_name, options)
      ActiveRecord::Base.logger.debug "Rendering %s" % file.inspect
      render :inline=>rhtml
    end

    private
      def arv_erb_code(buffer, arv_name, options)
        html  = ''
        array = buffer.scan(/^([^#]\S+?)\s*=(.*?)$/m)
        names = array.map(&:first)
        leads = array.map{|a| a.last.to_s.strip}

        names.each_with_index do |name, i|
          next if (lead = leads[i]).blank? and (i > 0)
          colspan = 1 + (leads[i+1..-1].map(&:blank?)+[false]).index(false)
          html << "<th class='%s' colspan=%d>%s</th>" % [name, colspan, lead]
        end
        options[:class] = "arv-list #{arv_name} #{options[:class]}".strip
        content_tag(:table, <<-ERB, options)
<thead><tr>#{html}</tr></thead>
<%= collection_tbody_for(@#{arv_name}, %w( #{names.join(' ')} )) %>
        ERB
      end

      # derived from Rails1.2 for Rails2.1
      def partial_pieces(partial_path)
        if partial_path.include?('/')
          return File.dirname(partial_path), File.basename(partial_path)
        else
          return controller.class.controller_path, partial_path
        end
      end

  end
end
