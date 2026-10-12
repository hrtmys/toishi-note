// A 409 means another device saved first; any other non-2xx is a failure
// the user must hear about, never a silent success.
export function saveOutcome(status) {
  if (status === 409) return "conflict"
  if (status >= 200 && status <= 299) return "saved"
  return "failed"
}

// The Fetch spec caps the bodies of all in-flight keepalive requests in one
// document at 64 KiB; past that, fetch() rejects instead of sending.
const KEEPALIVE_BUDGET = 65536

export function byteLength(body) {
  return new TextEncoder().encode(body).length
}

export function keepaliveEligible(body, inflightBytes) {
  return byteLength(body) + inflightBytes <= KEEPALIVE_BUDGET
}

// "warn" when leaving now could lose a save the keepalive flush can't carry.
export function leaveDecision({ queues }) {
  for (const queue of queues) {
    if (queue.held) {
      if (queue.wrapperConnected) return "warn"
      continue
    }
    if (queue.waiting) return "warn"
    if (queue.inFlight && queue.inFlightKeepalive === false) return "warn"
  }
  return "leave"
}

// A held note whose page has left can't explain a prompt, so it doesn't keep the listener.
export function unloadListenerNeeded(queues) {
  return queues.some((queue) => queue.hasUnsaved && !(queue.held && !queue.wrapperConnected))
}

export function titleSyncDecision({ ownUrl, noteUrl, incoming, current, lastServerValue, composing, titleSaveActive, focused }) {
  if (noteUrl !== ownUrl) return "ignore"
  if (incoming === current) return "noop"
  if (composing || titleSaveActive || current !== lastServerValue) return "skip"
  return focused ? "defer" : "apply"
}

export function visitDecision({ method, kind, frameHasNoteWrapper, queues, prefetchAttached, prefetchCounter, saveCounter }) {
  const leaveAlone = { pause: false, flush: false, dropPrefetch: false }
  if (method !== "GET" || kind === "prefetch") return leaveAlone
  if (kind !== "drive" && !(kind === "frame" && frameHasNoteWrapper)) return leaveAlone

  const unsaved = queues.some((queue) => !queue.held && queue.hasUnsaved)
  const dropPrefetch = prefetchAttached && (unsaved || prefetchCounter !== saveCounter)
  return { pause: unsaved, flush: unsaved, dropPrefetch }
}

// The banner only helps while its page is on screen; otherwise the edits
// are dropped and a toast names the note.
export function conflictRoute({ wrapperConnected, visitPaused, title, placeholder }) {
  const name = title || placeholder
  if (visitPaused) return { action: "toast_after_load", discard: true, title: name }
  if (!wrapperConnected) return { action: "toast_now", discard: true, title: name }
  return { action: "banner", discard: false, title: name }
}
