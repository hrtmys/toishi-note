module HomeHelper
  # Carries Organize context so #organize_or can redirect back to exactly
  # where it was. Plain hidden_field_tag, not f.hidden_field, so these
  # stay unscoped even inside a scoped form.
  def organize_context_fields
    safe_join([
      hidden_field_tag(:organize, true),
      hidden_field_tag(:notebook_id, @current_notebook&.id),
      hidden_field_tag(:folder_id, @current_folder&.id),
      hidden_field_tag(:note_id, @current_note&.id)
    ])
  end
end
