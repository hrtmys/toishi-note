class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    # member: a normal note-taking account. admin: manages logins only —
    # see docs/product/ux-roadmap.md.old's "Multiple accounts" section for why
    # the two are kept separate rather than one account doing both.
    add_column :users, :role, :integer, default: 0, null: false
    add_index :users, :role
  end
end
