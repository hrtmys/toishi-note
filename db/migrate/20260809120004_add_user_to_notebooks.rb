class AddUserToNotebooks < ActiveRecord::Migration[8.1]
  # Local to this migration on purpose — see backfill_and_require_item_positions.rb.
  # Associations included only so an orphaned notebook (see below) doesn't
  # leave its folders/notes/items behind as unreachable dead rows.
  class Notebook < ActiveRecord::Base
    has_many :folders, dependent: :destroy
    has_many :notes, dependent: :destroy
  end
  class Folder < ActiveRecord::Base
    has_many :notes, dependent: :destroy
  end
  class Note < ActiveRecord::Base
    has_many :todo_items, dependent: :destroy
    has_many :scrap_items, dependent: :destroy
  end
  class TodoItem < ActiveRecord::Base; end
  class ScrapItem < ActiveRecord::Base; end
  class User < ActiveRecord::Base
    enum :role, { member: 0, admin: 1 }, default: :member
  end

  def up
    add_reference :notebooks, :user, foreign_key: true

    # No meaningful "who owned this" to recover, so hand existing
    # notebooks to the first member account (never admin, which doesn't
    # take notes). With no member either, it's orphaned demo data — drop it.
    fallback_owner = User.member.order(:registered_at).first || User.order(:registered_at).first

    if fallback_owner
      Notebook.where(user_id: nil).update_all(user_id: fallback_owner.id)
    else
      Notebook.where(user_id: nil).destroy_all
    end

    change_column_null :notebooks, :user_id, false
  end

  def down
    change_column_null :notebooks, :user_id, true
    remove_reference :notebooks, :user, foreign_key: true
  end
end
