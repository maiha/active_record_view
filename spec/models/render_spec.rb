require File.dirname(__FILE__) + '/../spec_helper'

Arv = Struct.new(:name, :buffer, :options)
class Arv
  include ActionView::Helpers::TagHelper
  include ActiveRecordView::RenderArv

  def execute
    arv_erb_code(buffer, name, options || {}).gsub(/\n/, '')
  end
end

describe ActiveRecordView::RenderArv, "IDと名前のARV" do
  before(:each) do
    @arv = Arv.new(:records, <<-ARV)
id = ID
name = 名前
    ARV
  end

  it "IDと名前がTHに入る" do
    @arv.execute.should == (<<-ERB).gsub(/\n/, '')
<table class="arv-list records">
<thead>
<tr>
<th class='id' colspan=1>ID</th>
<th class='name' colspan=1>名前</th>
</tr>
</thead>
<%= collection_tbody_for(@records, %w( id name )) %>
</table>
    ERB
  end

  it ":classで指定したクラス名がtableに追加される" do
    @arv.options = { :class=>"simple" }
    @arv.execute.should == (<<-ERB).gsub(/\n/, '')
<table class="arv-list records simple">
<thead>
<tr>
<th class='id' colspan=1>ID</th>
<th class='name' colspan=1>名前</th>
</tr>
</thead>
<%= collection_tbody_for(@records, %w( id name )) %>
</table>
    ERB
  end
end


describe ActiveRecordView::RenderArv, "=を含まない場合" do
  before(:each) do
    @arv = Arv.new(:records, <<-ARV)
id = ID
age : 年齢
name = 名前
    ARV
  end

  it "=がない行は無視される" do
    @arv.execute.should == (<<-ERB).gsub(/\n/, '')
<table class="arv-list records">
<thead>
<tr>
<th class='id' colspan=1>ID</th>
<th class='name' colspan=1>名前</th>
</tr>
</thead>
<%= collection_tbody_for(@records, %w( id name )) %>
</table>
    ERB
  end
end


describe ActiveRecordView::RenderArv, "#を含む場合" do
  before(:each) do
    @arv = Arv.new(:records, <<-ARV)
id = ID
# age = 年齢
name = 名前
    ARV
  end

  it "先頭が#の行は無視される" do
    @arv.execute.should == (<<-ERB).gsub(/\n/, '')
<table class="arv-list records">
<thead>
<tr>
<th class='id' colspan=1>ID</th>
<th class='name' colspan=1>名前</th>
</tr>
</thead>
<%= collection_tbody_for(@records, %w( id name )) %>
</table>
    ERB
  end

  it "= 以降に#がある行は有効" do
    @arv.buffer = <<-ARV
id = ID
age = #年齢
name = 名前
    ARV
    @arv.execute.should == (<<-ERB).gsub(/\n/, '')
<table class="arv-list records">
<thead>
<tr>
<th class='id' colspan=1>ID</th>
<th class='age' colspan=1>#年齢</th>
<th class='name' colspan=1>名前</th>
</tr>
</thead>
<%= collection_tbody_for(@records, %w( id age name )) %>
</table>
    ERB
  end
end


describe ActiveRecordView::RenderArv, "名称が空白の場合" do
  before(:each) do
    @arv = Arv.new(:records, <<-ARV)
id = ID
name = 名前
age =
    ARV
  end

  it "最後の行が空白の場合、ひとつ前の名称がcolspan=2になる" do
    @arv.execute.should == (<<-ERB).gsub(/\n/, '')
<table class="arv-list records">
<thead>
<tr>
<th class='id' colspan=1>ID</th>
<th class='name' colspan=2>名前</th>
</tr>
</thead>
<%= collection_tbody_for(@records, %w( id name age )) %>
</table>
    ERB
  end

  it "途中の行が空白の場合、ひとつ前の名称がcolspan=2になる" do
    @arv.buffer = <<-ARV
id = ID
name =
age = 年齢
    ARV
    @arv.execute.should == (<<-ERB).gsub(/\n/, '')
<table class="arv-list records">
<thead>
<tr>
<th class='id' colspan=2>ID</th>
<th class='age' colspan=1>年齢</th>
</tr>
</thead>
<%= collection_tbody_for(@records, %w( id name age )) %>
</table>
    ERB
  end

  it "先頭の行が空白の場合、空白を無視して通常とおりcolspan=1として出力する" do
    @arv.buffer = <<-ARV
id =
name = 名前
age = 年齢
    ARV
    @arv.execute.should == (<<-ERB).gsub(/\n/, '')
<table class="arv-list records">
<thead>
<tr>
<th class='id' colspan=1></th>
<th class='name' colspan=1>名前</th>
<th class='age' colspan=1>年齢</th>
</tr>
</thead>
<%= collection_tbody_for(@records, %w( id name age )) %>
</table>
    ERB
  end

  it "先頭と次の行が空白の場合、名前が空のcolspan=2が出力される" do
    @arv.buffer = <<-ARV
id =
name =
age = 年齢
    ARV
    @arv.execute.should == (<<-ERB).gsub(/\n/, '')
<table class="arv-list records">
<thead>
<tr>
<th class='id' colspan=2></th>
<th class='age' colspan=1>年齢</th>
</tr>
</thead>
<%= collection_tbody_for(@records, %w( id name age )) %>
</table>
    ERB
  end

  it "3行とも全て場合、名前が空のcolspan=3が出力される" do
    @arv.buffer = <<-ARV
id =
name =
age =
    ARV
    @arv.execute.should == (<<-ERB).gsub(/\n/, '')
<table class="arv-list records">
<thead>
<tr>
<th class='id' colspan=3></th>
</tr>
</thead>
<%= collection_tbody_for(@records, %w( id name age )) %>
</table>
    ERB
  end
end
