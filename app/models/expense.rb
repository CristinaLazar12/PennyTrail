class Expense < ApplicationRecord
    CATEGORIES = [
        "Groceries",
        "Dining Out",
        "Transport",
        "Housing",
        "Utilities",
        "Shopping",
        "Health",
        "Entertainment",
        "Education",
        "Other"
        ].freeze

  validates :description, :spent_on, :category, presence: true
  validates :amount, presence: true,
                     numericality: { greater_than: 0 }
  validates :category, inclusion: { in: CATEGORIES }
end
