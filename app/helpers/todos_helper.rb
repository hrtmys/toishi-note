module TodosHelper
  def todos_paste_skip_text(skip)
    t("home.todos.paste.skip_reasons.#{skip.reason}", heading: skip.heading || t("home.todos.paste.no_heading"))
  end

  def todos_paste_due_text(due)
    due&.iso8601 || t("home.todos.paste.no_due")
  end
end
