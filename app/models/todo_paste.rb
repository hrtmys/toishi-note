# Parses pasted /todos.md Markdown (possibly AI-edited) into structured
# lines. Pure: no DB, no user — see TodoApplyPlan for binding/resolution.
class TodoPaste
  # Matches TodoItemsController::MAX_BULK_ENTRIES; enforced by callers,
  # not here, so a truncated preview can still be built for an over-cap paste.
  MAX_PASTE_LINES = 500

  Line = Struct.new(:heading, :checked, :content, :due, :id, :delete, keyword_init: true) do
    def delete?
      !!delete
    end
  end

  TASK_LINE = /\A- \[( |x)\] (.*)\z/
  LENIENT_TASK_LINE = /\A[ \t]*(?:[-*+]|\d{1,9}[.)]) \[( |x|X)\] (.*)\z/
  HEADING_LINE = /\A##\s*(.*)\z/
  LENIENT_HEADING_LINE = /\A\#{1,6} (.*)\z/
  TAG = /\A(.*?)[ \t\r\n\f\v]*(?:\((id|due):[ \t\r\n\f\v]*([^)]*)\)|（(id|due):[ \t\r\n\f\v]*([^）]*)）)\z/mi
  Span = Struct.new(:start, :stop, :value, :delete, keyword_init: true)
  VALID_ID_BODY = /\A([0-9a-z]+)(;delete!)?\z/
  VALID_DUE_VALUE = /\A(none|\d{4}-\d{2}-\d{2})\z/

  # Lenient is the bulk-add modal's grammar. Apply stays strict, so a loose
  # line such as a sub-step would otherwise become an unintended :add op.
  def self.parse(text, lenient: false)
    new(text, lenient: lenient)
  end

  attr_reader :lines

  def initialize(text, lenient: false)
    @lines = []
    @task_line = lenient ? LENIENT_TASK_LINE : TASK_LINE
    @heading_line = lenient ? LENIENT_HEADING_LINE : HEADING_LINE
    parse!(text.to_s)
  end

  private

  def parse!(text)
    heading = nil
    mode = :normal

    text.each_line do |raw|
      line = raw.chomp

      if mode == :in_details
        mode = :normal if line.include?("</details>")
        next
      end

      if line.include?("<details>")
        mode = :in_details
        next
      end

      if (title = line[@heading_line, 1])
        if title.strip == "Structure"
          mode = :in_structure
        else
          mode = :normal
          heading = title.strip.presence
        end
        next
      end

      next if mode == :in_structure

      next unless (match = @task_line.match(line))
      @lines << build_line(heading, match[1] != " ", match[2])
    end
  end

  def build_line(heading, checked, rest)
    content, id, delete, due = extract_tags(rest)
    Line.new(heading: heading, checked: checked, content: content.strip, due: due, id: id, delete: delete)
  end

  # An AI editing todos.md may reorder or mangle these tags; losing an id would
  # turn an update into a duplicate, and binding the wrong one would overwrite
  # another item, so repeated ids bind none. Cases: test/shared/todo_paste_cases.json.
  def extract_tags(rest)
    ids = []
    dues = []
    literal_due = false
    stop = rest.length

    while (match = TAG.match(rest[0, stop]))
      key = (match[2] || match[4]).downcase
      body = match[3] || match[5]
      start = match[1].length

      if key == "id"
        valid = VALID_ID_BODY.match(body)
        break if valid.nil?

        ids << Span.new(start: start, stop: stop, value: valid[1].to_i(36), delete: valid[2].present?)
      else
        break if literal_due || dues.any?

        due = parse_due(body)
        if due.nil?
          literal_due = true
        else
          dues << Span.new(start: start, stop: stop, value: due)
        end
      end

      stop = start
    end

    bound_id = ids.size == 1 ? ids.first : nil
    bound_due = dues.first
    consumed = [ bound_id, bound_due ].compact.sort_by { |span| -span.start }
    content = consumed.reduce(rest) { |text, span| text[0...span.start] + text[span.stop..] }

    [ content, bound_id&.value, bound_id&.delete || false, bound_due&.value ]
  end

  def parse_due(value)
    return :none if value == "none"
    return nil unless VALID_DUE_VALUE.match?(value)

    Date.iso8601(value)
  rescue ArgumentError
    nil
  end
end
