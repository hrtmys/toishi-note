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
#
# A note on locking: this app runs on SQLite (see config/database.yml).
# SQLite has no real per-row locking — Arel's SQLite visitor drops the
# `FOR UPDATE` clause entirely (arel/visitors/sqlite.rb,
# visit_Arel_Nodes_Lock), so `.lock`/`lock!` add no SQL of their own
# there. What actually provides the serialization below is that Rails'
# SQLite3Adapter opens every transaction with `BEGIN IMMEDIATE` (the
# default since Rails 7.1), which grabs SQLite's single file-level write
# lock at the *start* of the transaction — before any statement inside it
# runs — and holds it until commit/rollback. So as long as the read that
# decides a value happens inside a transaction (explicit here, or the
# implicit one every `save`/`create!` already opens), it's guaranteed to
# see every earlier transaction's fully-committed writes. `.lock`/`lock!`
# are kept anyway: they're free, correct, and portable to a database
# where `FOR UPDATE` is real row-level locking.
module Positioned
  extend ActiveSupport::Concern

  class_methods do
    # +parent_association+ is the belongs_to this hangs off. New records
    # append after the current highest sibling position.
    def positioned_within(parent_association)
      before_create do
        next if position.present?

        # save/create! already wraps this callback in a transaction, so
        # locking the parent here serializes concurrent creates under the
        # same parent on it: the second one's MAX query below only runs
        # once the first's create (and its transaction) has committed.
        parent = public_send(parent_association)
        parent.lock!
        siblings = parent.public_send(self.class.table_name)
        self.position = (siblings.maximum(:position) || 0) + 1
      end
    end
  end

  # Sets explicit order from a client-supplied +ordered_ids+ array.
  # +relation+ must already be scoped to the caller's own records — raises
  # RecordNotFound on a mismatched id set instead of corrupting order.
  def self.reposition!(relation, ordered_ids)
    ids = Array(ordered_ids).map(&:to_i)

    relation.model.transaction do
      # Lock every row in scope and re-derive the id set from inside the
      # transaction, right before writing, to shrink the TOCTOU window a
      # caller-side check (outside the transaction) would otherwise leave
      # open to a concurrent create/destroy in the same parent scope.
      current_ids = relation.lock.pluck(:id)
      raise ActiveRecord::RecordNotFound, "ordered_ids does not match #{relation.model.name} ids" unless ids.sort == current_ids.sort

      records = ids.map { |id| relation.find(id) }
      # Two passes through temporary, guaranteed-negative positions: the
      # unique (parent, position) index (see the migration that added it)
      # is checked immediately on every UPDATE, not deferred until commit,
      # so writing final positions directly in one pass can transiently
      # collide with another record's *current* position (e.g. moving
      # something into the slot it's about to vacate).
      records.each_with_index { |record, index| record.update_column(:position, -(index + 1)) }
      records.each_with_index { |record, index| record.update_column(:position, index + 1) }
    end
  end
end
