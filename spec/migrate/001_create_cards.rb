class CreateCards < Special::Migrations::Table
  column :type,    :string      # [STI]
  column :no,     :integer      # 0 No
  column :name,    :string      # 1 名前
  column :cost,    :integer     # 2 コスト
  column :kind,    :string      # 3 属性
  column :hp,      :integer     # 4 HP
  column :power,   :integer     # 5 POW
  column :block,   :integer     # 6 ブロック
  column :counter, :integer     # 7 カウンター
  column :capacity,:integer     # 8 チーム人数（魔法カード　守備時使用可１）
  column :skill_name, :string   # 9 スキル名
  column :skill_cost, :integer  # 10 スキルコスト
  column :member,  :string      # 11 構成
  column :help,    :string      # 12 せつめい
end
