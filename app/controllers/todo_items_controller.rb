class TodoItemsController < ApplicationController
  before_action :set_note

  def create
    content = params.permit(:content)[:content].to_s.strip
    return head :ok if content.blank? # silently no-op on blank submissions

    @item = @note.todo_items.build(content: content, due_date: params[:due_date].presence)
    if @item.save
      render turbo_stream: [
        turbo_stream.append("todo_list_#{@note.id}", partial: "todo_items/item", locals: { item: @item }),
        todo_progress_stream
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
        todo_progress_stream
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
      todo_progress_stream
    ]
  end

  # A pasted JSON array is meant for "a bunch of tasks from a checklist",
  # not a bulk-loading endpoint — cap it so one request can't create an
  # unbounded number of rows and tie up the shared DB/Puma workers.
  MAX_BULK_ENTRIES = 500

  # Bulk-imports TODOs from a pasted JSON array (strings, or objects with
  # "content" and an optional checked flag). The browser's live preview is
  # a UX aid only — this re-parses and re-validates independently.
  def bulk_create
    entries = Note.parse_bulk_todo_entries(params[:entries])
    return head :unprocessable_entity if entries.size > MAX_BULK_ENTRIES

    items = @note.build_bulk_todo_items(entries).select(&:save)

    render turbo_stream: [
      *items.map { |item| turbo_stream.append("todo_list_#{@note.id}", partial: "todo_items/item", locals: { item: item }) },
      todo_progress_stream
    ]
  end

  private

  def set_note
    @note = Current.user.notes.find(params[:note_id])
  end

  def todo_item_params
    params.permit(:is_checked)
  end

  # Shared across create/update/destroy/bulk_create — every action that
  # mutates a note's todo_items needs the progress bar re-rendered.
  def todo_progress_stream
    turbo_stream.replace("todo_progress_#{@note.id}", partial: "todo_items/progress", locals: { note: @note })
  end
end
