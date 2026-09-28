export const DEFAULT_SORT = Object.freeze({ mode: "updated", direction: "desc" })

// A-Z opens ascending; the date modes open newest first.
export function nextSortState(state, clickedMode) {
  if (clickedMode === state.mode) {
    return { mode: state.mode, direction: state.direction === "desc" ? "asc" : "desc" }
  }
  return { mode: clickedMode, direction: clickedMode === "title" ? "asc" : "desc" }
}

export function sortNoteEntries(entries, { mode, direction }) {
  const key = mode === "title" ? "title" : `${mode}At`
  const factor = direction === "asc" ? 1 : -1

  return [ ...entries ].sort((a, b) => {
    if (a.pinned !== b.pinned) return a.pinned ? -1 : 1

    if (mode === "title") return factor * a[key].localeCompare(b[key])
    return factor * (a[key] - b[key])
  })
}
