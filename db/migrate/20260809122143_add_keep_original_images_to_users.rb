class AddKeepOriginalImagesToUsers < ActiveRecord::Migration[8.1]
  def change
    # Default is compressed (WebP) — see the Image attachments section of
    # ux-roadmap.md.old. Only opt out if you need the original file.
    add_column :users, :keep_original_images, :boolean, default: false, null: false
  end
end
