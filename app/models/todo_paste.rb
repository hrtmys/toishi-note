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
  HEADING_LINE = /\A##\s*(.*)\z/
  ID_TAG = /\A(.*?)\s*\(id:\s*([^)]*)\)\z/m
  DUE_TAG = /\A(.*?)\s*\(due:\s*([^)]*)\)\z/m
  VALID_ID_BODY = /\A([0-9a-z]+)(;delete!)?\z/
  VALID_DUE_VALUE = /\A(none|\d{4}-\d{2}-\d{2})\z/

  def self.parse(text)
    new(text)
  end

  attr_reader :lines

  def initialize(text)
    @lines = []
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

      if (title = line[HEADING_LINE, 1])
        if title.strip == "Structure"
          mode = :in_structure
        else
          mode = :normal
          heading = title.strip.presence
        end
        next
      end

      next if mode == :in_structure

      next unless (match = TASK_LINE.match(line))
      @lines << build_line(heading, match[1] == "x", match[2])
    end
  end

  def build_line(heading, checked, rest)
    content, id, delete = extract_id(rest)
    content, due = extract_due(content)
    Line.new(heading: heading, checked: checked, content: content.strip, due: due, id: id, delete: delete)
  end

  # The id tag is the rightmost suffix. A body that doesn't cleanly match
  # <base36> or <base36>;delete! leaves the whole group as literal
  # content — fail-closed, so a typo'd command can never silently bind.
  def extract_id(rest)
    return [ rest, nil, false ] unless (match = ID_TAG.match(rest))

    pre, body = match[1], match[2]
    return [ rest, nil, false ] unless (valid = VALID_ID_BODY.match(body))

    [ pre, valid[1].to_i(36), valid[2].present? ]
  end

  def extract_due(content)
    return [ content, nil ] unless (match = DUE_TAG.match(content))

    pre, value = match[1], match[2]
    return [ content, nil ] unless VALID_DUE_VALUE.match?(value)

    due = value == "none" ? :none : Date.iso8601(value)
    [ pre, due ]
  rescue ArgumentError
    [ content, nil ]
  end
end
