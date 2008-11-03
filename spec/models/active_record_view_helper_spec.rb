require File.dirname(__FILE__) + '/../spec_helper'

include ActiveRecordView

class ViewContext
  include ActiveRecordView::Helper

  def define_method(name, code)
    instance_eval("def %s; %s; end" % [name, code])
  end

  def link_to_show(record = nil)
    "link_to_show(#{record.id})"
  end

  # Mocks
  def controller
    nil
  end

  def text_field_tag(object_name, column_name, *args)
    "text_field_tag(%s,%s)" % [object_name, column_name]
  end
end

class CardHelper < ViewContext
  def card_no(record)
    "No.%d" % record.no
  end

  def card_name(record)
    "%sカード" % record.name
  end

  def edit_card_name(record)
    "%sカードの編集" % record.name
  end
end

class MagicCardHelper < CardHelper
  def magic_name(record)
    "%s魔法カード" % record.name
  end

  def edit_magic_name(record)
    "%s魔法カードの編集" % record.name
  end
end

class DeckHelper < ViewContext
  def deck_name(record)
    "%sデッキ" % record.name
  end

  def edit_deck_name(record)
    "%sデッキの編集" % record.name
  end

  def kind(record)
    "kind(#{record.id})"
  end
end

class HashHelper < ViewContext
  def hash_name(record)
    "hash_name(%s)" % record[:name]
  end

  def edit_hash_name(record)
    "edit_hash_name(%s)" % record[:name]
  end
end

module NameAccessor
  def name(record)
    "name(%s)" % record[:name]
  end

  def edit_name(record)
    "edit_name(%s)" % record[:name]
  end
end


######################################################################
### カラム参照

describe ActiveRecordView::Helper, "カラム参照" do
  before(:each) do
    @card   = Card.new(:name=>"nksk", :no=>1, :cost=>2)
    @view   = ViewContext.new
    @engine = @view.find_active_record_view_engine(Card, :name)
  end

  it "Engines::DuckTypeが利用される" do
    @engine.class.should == Engines::DuckType
  end

  it "showメソッド" do
    @engine.show(@card).should == "nksk"
  end

  it "editメソッド" do
    @engine.edit(@card).should == "text_field_tag(card[name],nksk)"
  end
end

describe ActiveRecordView::Helper, "存在しないフィールド参照" do
  before(:each) do
    @card   = Card.new(:name=>"nksk", :no=>1, :cost=>2)
    @view   = ViewContext.new
    @engine = @view.find_active_record_view_engine(Card, :unknown_field)
  end

  it "Engines::Missingが利用される" do
    @engine.class.should == Engines::Missing
  end

  it "showメソッドは self[key] (=nil) を返す" do
    @engine.show(@card).should == nil
  end

  it "editメソッド" do
    @engine.edit(@card).should == "text_field_tag(card[unknown_field],)"
  end
end


######################################################################
### ヘルパ

describe ActiveRecordView::Helper, "ヘルパメソッド定義状態" do
  before(:each) do
    @card   = Card.new(:name=>"nksk", :no=>1, :cost=>2)
    @view   = CardHelper.new
    @engine = @view.find_active_record_view_engine(Card, :name)
  end

  it "Engines::Helperが利用される" do
    @engine.class.should == Engines::Helper
  end

  it "定義されたヘルパメソッドを呼び出す" do
    @engine.show(@card).should == "nkskカード"
  end

  it "定義されたヘルパメソッドを呼び出す(+prefix)" do
    @engine = @view.find_active_record_view_engine(Card, :name, "edit_")
    @engine.edit(@card).should == "nkskカードの編集"
  end

  it "ヘルパに定義されていない場合" do
    @engine = @view.find_active_record_view_engine(Card, :cost)
    @engine.show(@card).should == 2
  end

  it "クラス名なしの名前が直接ヘルパメソッドとして定義されている場合" do
    @engine = @view.find_active_record_view_engine(Card, :link_to_show)
    @engine.class.should == Engines::Helper

    @card.id = 1
    @engine.show(@card).should == "link_to_show(1)"
  end
end


describe ActiveRecordView::Helper, "継承したモデル+継承用ヘルパ" do
  before(:each) do
    @card   = Card::Magic.new(:name=>"nksk", :no=>1)
    @view   = MagicCardHelper.new
    @engine = @view.find_active_record_view_engine(Card::Magic, :name)
  end

  it "Engines::Helperが利用される" do
    @engine.class.should == Engines::Helper
  end

  it "継承用クラス用に定義されたヘルパメソッドを呼び出す" do
    @engine.show(@card).should == "nksk魔法カード"
  end

  it "継承用クラス用に定義されたヘルパメソッドを呼び出す(+prefix)" do
    @engine = @view.find_active_record_view_engine(Card::Magic, :name, "edit_")
    @engine.edit(@card).should == "nksk魔法カードの編集"
  end

  it "親クラス用に定義されたヘルパメソッドを呼び出す" do
    @engine = @view.find_active_record_view_engine(Card::Magic, :no)
    @engine.show(@card).should == "No.1"
  end
end


describe ActiveRecordView::Helper, "継承したモデル+親クラス用ヘルパ" do
  before(:each) do
    @card   = Card::Magic.new(:name=>"nksk", :no=>1)
    @view   = CardHelper.new
    @engine = @view.find_active_record_view_engine(Card::Magic, :name)
  end

  it "Engines::Helperが利用される" do
    @engine.class.should == Engines::Helper
  end

  it "親クラス用に定義されたヘルパメソッドを呼び出す(継承用ヘルパにはある内容)" do
    @engine.show(@card).should == "nkskカード"
  end

  it "親クラス用に定義されたヘルパメソッドを呼び出す(継承用ヘルパにはある内容+prefix)" do
    @engine = @view.find_active_record_view_engine(Card::Magic, :name, "edit_")
    @engine.edit(@card).should == "nkskカードの編集"
  end

  it "親クラス用に定義されたヘルパメソッドを呼び出す" do
    @engine = @view.find_active_record_view_engine(Card::Magic, :no)
    @engine.show(@card).should == "No.1"
  end
end

######################################################################
### プロパティ

describe ActiveRecordView::Helper, "プロパティ定義状態" do
  before(:each) do
    @deck   = Deck.new(:name=>"nksk", :word=>"qff")
    @view   = ViewContext.new
    @engine = @view.find_active_record_view_engine(Deck, :name)
  end

  it "Engines::Propertyが利用される" do
    @engine.class.should == Engines::Property
  end

  it "プロパティの値を参照(show)" do
    @engine.show(@deck).should == "nksk"
  end

  it "プロパティの値を参照(edit)" do
    @engine.edit(@deck).should == '<input class="name" id="deck_name" name="deck[name]" size="30" type="text" value="nksk" />'
  end
end


######################################################################
### プロパティ + ヘルパ

describe ActiveRecordView::Helper, "プロパティとヘルパが定義された状態" do
  before(:each) do
    @deck   = Deck.new(:name=>"nksk", :word=>"qff")
    @view   = DeckHelper.new
  end

  it "nameカラムはヘルパに定義されているのでEngines::Helperが利用される" do
    @engine = @view.find_active_record_view_engine(Deck, :name)
    @engine.class.should == Engines::Helper
  end

  it "nameカラムの参照はヘルパの実行になる" do
    @engine = @view.find_active_record_view_engine(Deck, :name)
    @engine.show(@deck).should == "nkskデッキ"
  end

  it "nameカラムの編集はヘルパの実行になる" do
    @engine = @view.find_active_record_view_engine(Deck, :name, "edit_")
    @engine.edit(@deck).should == "nkskデッキの編集"
  end

  it "wordカラムの参照はヘルパに定義されてないのでEngines::Propertyが利用される" do
    @engine = @view.find_active_record_view_engine(Deck, :word)
    @engine.class.should == Engines::Property
  end

  it "wordカラムの修整はヘルパに定義されてないのでEngines::Propertyが利用される" do
    @engine = @view.find_active_record_view_engine(Deck, :word, "edit_")
    @engine.class.should == Engines::Property
    @engine.edit(@deck).should == '<textarea class="word" cols="80" id="deck_word" name="deck[word]" rows="5">qff</textarea>'
  end

  it "カラム名が直接ヘルパメソッドとして定義されている場合でもプロパティが優先される" do
    @engine = @view.find_active_record_view_engine(Deck, :kind)
    @engine.class.should == Engines::Property
  end

  it "クラス名なしの名前が直接ヘルパメソッドとして定義されており、それがカラム名でなければヘルパが利用される" do
    @engine = @view.find_active_record_view_engine(Deck, :link_to_show)
    @engine.class.should == Engines::Helper

    @deck.id = 1
    @engine.show(@deck).should == "link_to_show(1)"
  end
end


######################################################################
### 入力フォームにて指定されたパラメータ名を優先させる

describe ActiveRecordView::Helper, "Property時のパラメータ指定" do
  before(:each) do
    @deck = Deck.new(:name=>"nksk", :word=>"qff")
    @view = ViewContext.new
  end

  it "data というパラメータ名で入力フォームを作る" do
    @engine = @view.find_active_record_view_engine(Deck, :name)
    @engine.class.should == Engines::Property
    @engine.edit(@deck, :name, @view, :data).should ==
      '<input class="name" id="data_name" name="data[name]" size="30" type="text" value="nksk" />'
  end
end


######################################################################
### 非ActiveRecord

describe ActiveRecordView::Helper, "Hashオブジェクトでヘルパあり" do
  before(:each) do
    @record = {:name=>"nksk"}
    @view   = HashHelper.new
    @engine = @view.find_active_record_view_engine(Hash, :name)
  end

  it "Engines::Helperが利用される" do
    @engine.class.should == Engines::Helper
  end

  it "定義されたヘルパメソッドを呼び出す" do
    @engine.show(@record).should == "hash_name(nksk)"
  end
end

describe ActiveRecordView::Helper, "Hashオブジェクトでメソッド名ヘルパあり" do
  before(:each) do
    @record = {:name=>"nksk"}
    @view   = ViewContext.new
    @view.extend NameAccessor
    @engine = @view.find_active_record_view_engine(Hash, :name)
  end

  it "Engines::Helperが利用される" do
    @engine.class.should == Engines::Helper
  end

  it "定義されたヘルパメソッドを呼び出す" do
    @engine.show(@record).should == "name(nksk)"
  end
end

describe ActiveRecordView::Helper, "Hashオブジェクトでクラス名とメソッド名の両ヘルパあり" do
  before(:each) do
    @record = {:name=>"nksk"}
    @view   = HashHelper.new
    @view.extend NameAccessor
    @engine = @view.find_active_record_view_engine(Hash, :name)
  end

  it "Engines::Helperが利用される" do
    @engine.class.should == Engines::Helper
  end

  it "定義されたヘルパメソッドを呼び出す" do
    # クラス名のヘルパが優先される
    @engine.show(@record).should == "hash_name(nksk)"
  end
end

describe ActiveRecordView::Helper, "Hashオブジェクトでヘルパなし" do
  before(:each) do
    @record = {:name=>"nksk"}
    @view   = ViewContext.new
    @engine = @view.find_active_record_view_engine(Hash, :name)
  end

  it "Engines::Missingが利用される" do
    @engine.class.should == Engines::Missing
  end

  it "showメソッド" do
    @engine.show(@record).should == "nksk"
  end

  it "editメソッド" do
    @engine.edit(@record).should == "text_field_tag(hash[name],nksk)"
  end
end


# describe ActiveRecordView::Helper, "[] メソッドを持たないオブジェクト" do
#   it "TypeError が起きる" do
#     @engine = @view.find_active_record_view_engine(Integer, :name)
# #  raise TypeError, "expect '[]' accessor for #{klass}"
#   end
# end

