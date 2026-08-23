class AddTrustedHeaderOwnerToUsers < ActiveRecord::Migration[8.1]
  def change
    # Marks the single account a solo trusted-header deployment always
    # signs into. Team deployments never set this; the partial unique
    # index guarantees at most one row ever claims it.
    add_column :users, :trusted_header_owner, :boolean, default: false, null: false
    add_index :users, :trusted_header_owner, unique: true, where: "trusted_header_owner"
  end
end
