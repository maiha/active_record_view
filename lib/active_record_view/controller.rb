module ActiveRecordView::Controller
  include ActiveRecordView::RenderArv

  def render_arv(arv, options = {})
    add_variables_to_assigns
    response.body = @template.render_arv(arv, options)
    @performed_render = true
  end
end
