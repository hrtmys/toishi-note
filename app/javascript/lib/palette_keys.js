// Command palette key decisions; the controller owns the modal and DOM.

export function isPaletteShortcut(event) {
  if (event.isComposing) return false
  return (event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "p"
}

const ACTIONS = { ArrowDown: "next", ArrowUp: "previous", Enter: "visit", Escape: "close" }

export function paletteKeyAction(event) {
  // Enter mid-composition confirms the IME conversion, not a result.
  if (event.isComposing) return null
  return ACTIONS[event.key] ?? null
}

export function wrapIndex(current, delta, length) {
  if (length === 0) return -1
  const from = current === -1 ? 0 : current
  return (from + delta + length) % length
}
