class CreateExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :expenses do |t|
      t.string :description
      t.decimal :amount, precision: 12, scale: 2
      t.date :spent_on
      t.string :category

      t.timestamps
    end
  end
end
