class ScrapItem < ApplicationRecord
  include Positioned

  belongs_to :note
  positioned_within :note

  validates :content, presence: true
end
