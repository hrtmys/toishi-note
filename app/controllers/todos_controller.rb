# /todos.html redirects into the Todos mode of the main pane
# (HomeController#index) — kept only so old links/bookmarks still resolve.
# /todos.md is the AI handoff — see TodoHandoff.
class TodosController < ApplicationController
  SCOPE_PARAMS = %i[note_id folder_id notebook_id].freeze

  def index
    respond_to do |format|
      format.html { redirect_to root_path(todos: true) }
      format.md { render_handoff }
    end
  end

  private

  def render_handoff
    return head :not_found unless Current.user.ai_handoff_enabled?

    scope = resolve_scope
    return head :not_found if scope == :not_found

    render plain: TodoHandoff.new(user: Current.user, scope: scope).to_markdown, content_type: "text/markdown"
  end

  # nil means "no scope" (the whole account); :not_found means a param was
  # given but didn't resolve — never fall back to nil, or an unrecognised
  # id would silently widen the scope to everything.
  def resolve_scope
    key = SCOPE_PARAMS.find { |param| params[param].present? }
    return nil if key.nil?

    value = params[key]
    return :not_found unless value.is_a?(String) && value.match?(/\A\d+\z/)

    resolve_scope_record(key, value) || :not_found
  rescue ActiveModel::RangeError, ActiveRecord::RangeError
    :not_found
  end

  def resolve_scope_record(key, value)
    case key
    when :note_id then Current.user.notes.find_by(id: value)
    when :folder_id then Current.user.folders.find_by(id: value)
    when :notebook_id then Current.user.notebooks.find_by(id: value)
    end
  end
end
