class TodoItemsController < ApplicationController
  before_action :set_note

  def create
    content = params.permit(:content)[:content].to_s.strip
    return head :ok if content.blank? # silently no-op on blank submissions

    @item = @note.todo_items.build(content: content, due_date: params[:due_date].presence)
    if @item.save
      render turbo_stream: [
        turbo_stream.append("todo_list_#{@note.id}", partial: "todo_items/item", locals: { item: @item }),
        turbo_stream.replace("todo_progress_#{@note.id}", partial: "todo_items/progress", locals: { note: @note })
      ]
    else
      head :unprocessable_entity
    end
  end

  def update
    @item = @note.todo_items.find(params[:id])
    if @item.update(todo_item_params)
      streams = [
        turbo_stream.replace("todo_item_#{@item.id}", partial: "todo_items/item", locals: { item: @item }),
        turbo_stream.replace("todo_progress_#{@note.id}", partial: "todo_items/progress", locals: { note: @note })
      ]
      # The "All open TODOs" cross-notebook view only lists unchecked
      # items, so checking one off there should remove it, not re-render.
      streams << turbo_stream.remove("all_todos_item_#{@item.id}") if @item.is_checked?
      render turbo_stream: streams
    else
      head :unprocessable_entity
    end
  end

  def destroy
    @item = @note.todo_items.find(params[:id])
    @item.destroy!
    render turbo_stream: [
      turbo_stream.remove("todo_item_#{@item.id}"),
      turbo_stream.replace("todo_progress_#{@note.id}", partial: "todo_items/progress", locals: { note: @note })
    ]
  end

  # Bulk-imports TODOs from a pasted JSON array (strings, or objects with
  # "content" and an optional checked flag). The browser's live preview is
  # a UX aid only — this re-parses and re-validates independently.
  def bulk_create
    items = todo_items_from_bulk_json(params[:entries]).select(&:save)

    render turbo_stream: [
      *items.map { |item| turbo_stream.append("todo_list_#{@note.id}", partial: "todo_items/item", locals: { item: item }) },
      turbo_stream.replace("todo_progress_#{@note.id}", partial: "todo_items/progress", locals: { note: @note })
    ]
  end

  private

  def set_note
    @note = Current.user.notes.find(params[:note_id])
  end

  def todo_item_params
    params.permit(:is_checked)
  end

  def todo_items_from_bulk_json(raw)
    parsed = JSON.parse(raw.to_s)
    return [] unless parsed.is_a?(Array)

    parsed.filter_map { |entry| build_bulk_todo_item(entry) }
  rescue JSON::ParserError
    []
  end

  def build_bulk_todo_item(entry)
    content, checked =
      case entry
      when String
        [ entry, false ]
      when Hash
        [ entry["content"], entry.values_at("checked", "is_checked", "done").compact.first ]
      end

    return if content.to_s.strip.blank?

    @note.todo_items.build(content: content.to_s.strip, is_checked: !!checked)
  end
end
