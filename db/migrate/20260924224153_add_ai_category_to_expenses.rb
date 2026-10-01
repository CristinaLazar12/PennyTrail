class AddAiCategoryToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses, :ai_category, :string
  end
end
