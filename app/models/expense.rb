class Expense < ApplicationRecord
  validates :description, :spent_on, :category, presence: true
  validates :amount, presence: true,
                     numericality: { greater_than: 0 }
end
