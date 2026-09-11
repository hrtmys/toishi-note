// List-marker parsing shared with the list continuation UI.
// Unit-tested; the controller owns key handling on top of these.

// Recognizes five marker shapes: "-", "*", "1.", "- [ ]" (task list),
// and ">". Task-list is checked first since it's a superset of bare bullet.
export function parseListMarker(line) {
  let m

  m = line.match(/^(\s*)([-*])(\s+)\[([ xX])\](\s*)/)
  if (m) {
    return {
      full: m[0],
      rest: line.slice(m[0].length),
      // A continued task starts unchecked, regardless of whether the
      // item it followed was checked — carrying a checkmark forward
      // onto a brand new, not-yet-done item would be actively wrong.
      continued: `${m[1]}${m[2]}${m[3]}[ ]${m[5]}`
    }
  }

  m = line.match(/^(\s*)([-*])(\s+)/)
  if (m) {
    return { full: m[0], rest: line.slice(m[0].length), continued: m[0] }
  }

  m = line.match(/^(\s*)(\d+)([.)])(\s+)/)
  if (m) {
    const nextNumber = parseInt(m[2], 10) + 1
    return {
      full: m[0],
      rest: line.slice(m[0].length),
      continued: `${m[1]}${nextNumber}${m[3]}${m[4]}`,
      // The renumber step needs these back to fix up the lines below a
      // continued item; bullets/task items/quote never renumber.
      ordered: { indent: m[1], number: parseInt(m[2], 10), delimiter: m[3] }
    }
  }

  m = line.match(/^(\s*)(>)(\s*)/)
  if (m) {
    return { full: m[0], rest: line.slice(m[0].length), continued: m[0] }
  }

  return null
}

export function currentLine(value, caretPosition) {
  const lineStart = value.lastIndexOf("\n", caretPosition - 1) + 1
  const nextNewline = value.indexOf("\n", caretPosition)
  const lineEnd = nextNewline === -1 ? value.length : nextNewline
  return { lineStart, lineEnd, line: value.slice(lineStart, lineEnd) }
}

// Renumbers consecutive same-indent ordered lines below lineEnd so a
// continued item keeps the sequence. Returns null when nothing follows.
export function renumberFollowingLines(value, lineEnd, indent, firstNumber) {
  if (value[lineEnd] !== "\n") return null

  let pos = lineEnd + 1
  let number = firstNumber
  let text = ""
  let end = lineEnd

  for (;;) {
    const nextNewline = value.indexOf("\n", pos)
    const followerEnd = nextNewline === -1 ? value.length : nextNewline
    const follower = value.slice(pos, followerEnd)
    const m = follower.match(/^(\s*)(\d+)([.)])(\s+)(.*)$/)
    if (!m || m[1] !== indent) break

    text += `\n${indent}${number}${m[3]}${m[4]}${m[5]}`
    end = followerEnd
    number += 1
    if (nextNewline === -1) break
    pos = followerEnd + 1
  }

  if (end === lineEnd) return null
  return { end, text }
}
