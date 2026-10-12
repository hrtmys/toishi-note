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
  TAG = /\A(.*?)\s*\((id|due):\s*([^)]*)\)\z/m
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
    content, id, delete, due = extract_tags(rest)
    Line.new(heading: heading, checked: checked, content: content.strip, due: due, id: id, delete: delete)
  end

  # Strips trailing (id: …) and (due: …) tags from the end, in either order,
  # each at most once. A malformed id stops the scan. A malformed due stays
  # literal content, but an id to its left still binds; a due to its left does not.
  def extract_tags(rest)
    current = rest
    seen = {}
    id = nil
    delete = false
    due = nil
    literal = []

    while (match = TAG.match(current))
      key, body = match[2], match[3]
      break if seen[key]
      break if key == "due" && literal.any?

      if key == "id"
        valid = VALID_ID_BODY.match(body)
        break if valid.nil?

        id = valid[1].to_i(36)
        delete = valid[2].present?
        seen[key] = true
      elsif (parsed = parse_due(body))
        due = parsed
        seen[key] = true
      else
        literal.unshift(current[match[1].length..])
      end

      current = match[1]
    end

    [ current + literal.join, id, delete, due ]
  end

  def parse_due(value)
    return :none if value == "none"
    return nil unless VALID_DUE_VALUE.match?(value)

    Date.iso8601(value)
  rescue ArgumentError
    nil
  end
end
