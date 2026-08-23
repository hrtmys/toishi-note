# Assigns a sequential +position+ on create, scoped to a parent
# association, so display order comes from an explicit column instead of
# leaning on +created_at+.
#
# Usage:
#   class TodoItem < ApplicationRecord
#     include Positioned
#     belongs_to :note
#     positioned_within :note
#   end
module Positioned
  extend ActiveSupport::Concern

  class_methods do
    # +parent_association+ is the belongs_to this hangs off. New records
    # append after the current highest sibling position.
    def positioned_within(parent_association)
      before_create do
        next if position.present?

        siblings = public_send(parent_association).public_send(self.class.table_name)
        self.position = (siblings.maximum(:position) || 0) + 1
      end
    end
  end

  # Sets explicit order from a client-supplied +ordered_ids+ array.
  # +relation+ must already be scoped to the caller's own records — raises
  # RecordNotFound on a mismatched id set instead of corrupting order.
  def self.reposition!(relation, ordered_ids)
    ids = Array(ordered_ids).map(&:to_i)
    raise ActiveRecord::RecordNotFound, "ordered_ids does not match #{relation.model.name} ids" unless ids.sort == relation.ids.sort

    ids.each_with_index do |id, index|
      relation.find(id).update_column(:position, index + 1)
    end
  end
end
