// Text transforms shared with the Quick Formatting UI.
// Unit-tested; the controller owns DOM wiring on top of these.

export function fullwidthToHalfwidth(text) {
  return text.replace(/[０-９]/g, ch => String.fromCharCode(ch.charCodeAt(0) - 0xFEE0))
}

export function removePunctuationSpace(text) {
  // Remove spaces after Japanese punctuation marks
  return text.replace(/([、。])\s+/g, "$1")
}

export function removeNumberJpSpace(text) {
  // Remove spaces between numbers and Japanese characters
  return text.replace(/([0-9])\s+([ぁ-んァ-ン一-龯])/g, "$1$2")
}

export function collapseNewlines(text) {
  // Replace two or more consecutive newlines with a single newline
  return text.replace(/\n{2,}/g, "\n")
}

export function removeBracketed(text) {
  // Remove content inside square brackets, including the brackets
  return text.replace(/\[[^\]]*\]/g, "")
}

// Run in a fixed order so results are deterministic regardless of
// checkbox DOM order: bracket removal can leave blank lines behind,
// so newline collapsing must run last to normalize the final result.
export const TEXT_FORMAT_ORDER = [
  "fullwidth_to_halfwidth",
  "punctuation_space",
  "number_jp_space",
  "remove_brackets",
  "collapse_newlines"
]

const TRANSFORMS = {
  fullwidth_to_halfwidth: fullwidthToHalfwidth,
  punctuation_space: removePunctuationSpace,
  number_jp_space: removeNumberJpSpace,
  collapse_newlines: collapseNewlines,
  remove_brackets: removeBracketed
}

export function applyTextTransforms(text, selectedOptions) {
  const ordered = TEXT_FORMAT_ORDER.filter(opt => selectedOptions.includes(opt))
  ordered.forEach(opt => {
    text = TRANSFORMS[opt](text)
  })
  return text
}
