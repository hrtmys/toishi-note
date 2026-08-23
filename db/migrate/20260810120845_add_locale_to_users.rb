class AddLocaleToUsers < ActiveRecord::Migration[8.1]
  def change
    # No default, nullable — nil means "no explicit preference yet,"
    # backfilled by ApplicationController#switch_locale on first request
    # so every signup path gets it for free.
    add_column :users, :locale, :string
  end
end
