class TodoItem < ApplicationRecord
  include Positioned

  belongs_to :note
  positioned_within :note

  validates :content, presence: true

  def overdue?
    due_date.present? && !is_checked && due_date < Date.current
  end
end
