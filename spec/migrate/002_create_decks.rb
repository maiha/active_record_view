class CreateDecks < Special::Migrations::Table
  column :name,   :string
  column :kind,   :string
  column :word,   :string
end
