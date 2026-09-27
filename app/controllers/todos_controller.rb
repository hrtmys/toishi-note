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

  # Renders the operation list for a pasted text, with a digest of the
  # resolved plan carried in a hidden field for #apply to verify against.
  def preview
    return head :not_found unless Current.user.ai_handoff_enabled?

    text = params[:text].to_s
    lines = TodoPaste.parse(text).lines
    return over_cap_response("todos_paste_preview") if lines.size > TodoPaste::MAX_PASTE_LINES

    plan = TodoApplyPlan.new(lines, user: Current.user)
    render turbo_stream: turbo_stream.update("todos_paste_preview",
      partial: "todos/paste_preview",
      locals: { plan: plan, text: text, digest: TodoApplyPlanDigest.for(plan), any_lines: lines.any?, view: todos_view_param })
  end

  # Re-parses +text+ and re-resolves it inside the transaction, so the
  # apply always acts on the plan as it is right now, not as it was when
  # the preview was rendered — see TodoApplyPlanApplier.
  def apply
    return head :not_found unless Current.user.ai_handoff_enabled?

    text = params[:text].to_s
    return over_cap_response("todos_paste_preview") if TodoPaste.parse(text).lines.size > TodoPaste::MAX_PASTE_LINES

    plan = TodoApplyPlanApplier.apply!(text: text, digest: params[:digest], user: Current.user)
    return digest_mismatch_response if plan.nil?

    render turbo_stream: apply_streams(plan)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
    render turbo_stream: message_stream(t("home.todos.paste.apply_failed")), status: :unprocessable_entity
  end

  private

  def todos_view_param
    params[:view].in?(%w[project due]) ? params[:view] : "project"
  end

  def over_cap_response(target)
    render turbo_stream: message_stream(t("home.todos.paste.over_cap"), target: target), status: :unprocessable_entity
  end

  def digest_mismatch_response
    render turbo_stream: message_stream(t("home.todos.paste.digest_mismatch")), status: :unprocessable_entity
  end

  def message_stream(text, target: "todos_paste_preview")
    turbo_stream.update(target, partial: "todos/paste_message", locals: { message: text })
  end

  # A touched note can appear or vanish from the hub's listing entirely
  # (its last open item gets added/checked off), so the body is re-queried
  # rather than patched operation-by-operation.
  def apply_streams(plan)
    view = todos_view_param
    body = if view == "due"
      render_to_string(partial: "home/todos_due", locals: { todo_items: Current.user.open_todo_items_by_due })
    else
      render_to_string(partial: "home/todos_project", locals: { todo_notes: Current.user.open_todo_notes })
    end

    [ turbo_stream.replace("todos_hub_body") { body }, message_stream(t("home.todos.paste.applied")) ]
  end

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
