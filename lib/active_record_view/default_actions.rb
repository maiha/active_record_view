module ActiveRecordView::DefaultActions
  def link_to_new(record = nil)
    link_to "追加", :action=>"new"
  end

  def link_to_list(record = nil)
    link_to "一覧", :action=>"list"
  end

  def link_to_show(record)
    link_to "参照", :action=>"show", :id=>record
  end

  def link_to_edit(record)
    link_to "修正", :action=>"edit", :id=>record
  end

  def link_to_destroy(record)
    link_to "削除", {:action=>"destroy", :id=>record}, :confirm=>"本当に削除しますか？", :method => "post"
  end

  def link_to_save(record)
    if record.new_record?
      link_to "作成", :action=>"create", :id=>record
    else
      link_to "更新", :action=>"update", :id=>record
    end
  end
end
