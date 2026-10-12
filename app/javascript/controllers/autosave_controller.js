import { Controller } from "@hotwired/stimulus"
import { StreamActions } from "@hotwired/turbo"
import { t } from "../lib/translations"
import { byteLength, conflictRoute, keepaliveEligible, leaveDecision, saveOutcome, titleSyncDecision, unloadListenerNeeded, visitDecision } from "../lib/autosave"
import { allNoteQueues, findNoteQueue, noteQueue } from "../lib/save_queue"

const VISIT_PAUSE_CAP_MS = 5000

let inflightKeepaliveBytes = 0
// Bumped on every save sent or settled, so a prefetch taken before a save can be told apart.
let saveCounter = 0
const prefetchCounters = new Map()
let pausedVisit = null

export function queueForNote(noteUrl, version) {
  return noteQueue(noteUrl, { version: version ?? 0, send: transport(noteUrl), onChange: queueChanged })
}

export function adoptNoteVersion(noteUrl, version) {
  const queue = findNoteQueue(noteUrl)
  if (!queue) return
  queue.adopt(version)
  writeWrapperVersion(queue)
}

export function writeWrapperVersion(queue) {
  if (queue.wrapperConnected) queue.wrapper.dataset.noteLockVersion = queue.version
}

// Belongs to no controller, so a save outlives the field that scheduled it.
// Everything up to fetch() stays synchronous: an unload flush must reach it.
function transport(noteUrl) {
  return async ({ field, value, version }) => {
    const queue = findNoteQueue(noteUrl)
    const body = JSON.stringify({ note: { [field]: value, lock_version: version } })
    const bytes = byteLength(body)
    const keepalive = keepaliveEligible(body, inflightKeepaliveBytes)
    if (keepalive) inflightKeepaliveBytes += bytes
    queue.inFlightKeepalive = keepalive
    saveCounter++

    try {
      const response = await window.fetch(noteUrl, {
        method: "PUT",
        keepalive,
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html, application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body
      })

      const header = response.headers.get("X-Note-Lock-Version")
      const result = { status: response.status, version: header === null ? null : Number(header) }

      // Only a 2xx body is a turbo stream; a 422/500 page rendered as one
      // would throw an obscure JS error instead of the save-failed toast.
      if (saveOutcome(response.status) === "saved") {
        const html = await response.text()
        if (html) window.Turbo.renderStreamMessage(html)
      }
      return result
    } catch (error) {
      console.error("Failed to autosave", error)
      throw error
    } finally {
      if (keepalive) inflightKeepaliveBytes -= bytes
      saveCounter++
    }
  }
}

function queueChanged(queue) {
  writeWrapperVersion(queue)
  refreshLeaveListener()
}

function flushAll() {
  allNoteQueues().forEach((queue) => queue.flush())
}

function warnIfLeavingLosesSaves(event) {
  flushAll()
  const queues = allNoteQueues().map((queue) => ({
    held: queue.held && queue.hasUnsaved,
    wrapperConnected: queue.wrapperConnected,
    inFlight: queue.inFlight,
    inFlightKeepalive: queue.inFlightKeepalive,
    waiting: queue.pending.size > 0,
    lowered: queue.lowered && queue.hasUnsaved
  }))
  if (leaveDecision({ queues }) === "warn") {
    event.preventDefault()
    event.returnValue = ""
  }
}

// Registered only while needed: any beforeunload listener keeps the page out of the bfcache.
function refreshLeaveListener() {
  if (unloadListenerNeeded(allNoteQueues())) {
    window.addEventListener("beforeunload", warnIfLeavingLosesSaves)
  } else {
    window.removeEventListener("beforeunload", warnIfLeavingLosesSaves)
  }
}

window.addEventListener("pagehide", flushAll)
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "hidden") flushAll()
})

function takePrefetchCounter(kind, href) {
  if (kind === "prefetch") return null
  const counter = prefetchCounters.get(href) ?? null
  prefetchCounters.delete(href)
  return counter
}

function requestKind(event) {
  if (event.detail.fetchOptions.headers?.["X-Sec-Purpose"] === "prefetch") return "prefetch"
  if (event.target === document.documentElement) return "drive"
  if (event.target.tagName === "TURBO-FRAME") return "frame"
  return "other"
}

// Bubble phase on document, so Turbo's capture-phase listener has already
// attached any prefetched request this visit would reuse.
document.addEventListener("turbo:before-fetch-request", (event) => {
  const { detail } = event
  const kind = requestKind(event)
  const queues = allNoteQueues()
  const decision = visitDecision({
    method: String(detail.fetchOptions.method || "GET").toUpperCase(),
    kind,
    frameHasNoteWrapper: kind === "frame" && Boolean(event.target.querySelector("[data-note-url]")),
    queues: queues.map((queue) => ({ held: queue.held, lowered: queue.lowered, hasUnsaved: queue.hasUnsaved })),
    prefetchAttached: Boolean(detail.fetchRequest),
    prefetchCounter: takePrefetchCounter(kind, detail.url.href),
    saveCounter
  })

  if (kind === "prefetch") prefetchCounters.set(detail.url.href, saveCounter)
  if (decision.block) {
    // Never resumed: the visit is abandoned so the banner stays on screen.
    event.preventDefault()
    showLoweredConflicts(queues)
    return
  }
  if (!decision.pause) {
    if (decision.dropPrefetch) delete detail.fetchRequest
    return
  }

  queues.forEach((queue) => queue.flush())
  event.preventDefault()
  const visit = { kind, target: event.target }
  pausedVisit = visit
  Promise.all(queues.map((queue) => queue.waitForPending(VISIT_PAUSE_CAP_MS))).then(() => {
    delete detail.fetchRequest
    if (pausedVisit === visit) pausedVisit = null
    detail.resume()
  })
})

function showLoweredConflicts(queues) {
  queues.filter((queue) => queue.lowered && queue.hasUnsaved && queue.wrapperConnected)
    .forEach((queue) => queue.wrapper.dispatchEvent(new CustomEvent("note:conflict", { bubbles: true })))
}

// Cancelling here keeps Drive from starting a visit it can't finish.
document.addEventListener("turbo:before-visit", (event) => {
  const queues = allNoteQueues()
  const decision = visitDecision({
    method: "GET",
    kind: "drive",
    frameHasNoteWrapper: false,
    queues: queues.map((queue) => ({ held: queue.held, lowered: queue.lowered, hasUnsaved: queue.hasUnsaved })),
    prefetchAttached: false,
    prefetchCounter: null,
    saveCounter
  })
  if (!decision.block) return
  event.preventDefault()
  showLoweredConflicts(queues)
})

// The server sends the auto-title as an attribute; the field decides whether to show it.
StreamActions.server_value = function () {
  const detail = { value: this.getAttribute("value"), noteUrl: this.getAttribute("note-url") }
  this.targetElements.forEach((element) => element.dispatchEvent(new CustomEvent("autosave:server-value", { detail })))
}

function toast(message) {
  window.dispatchEvent(new CustomEvent("toast:show", { detail: { message } }))
}

// The toast element is replaced with the page, so it waits for the next render.
function toastAfterVisit(message, visit) {
  const loadEvent = visit.kind === "frame" ? "turbo:frame-load" : "turbo:load"
  // Each of these means the paused request will never render.
  const events = [ loadEvent, "turbo:visit", "turbo:fetch-request-error" ]
  if (visit.kind === "frame") events.push("turbo:frame-missing", "turbo:before-fetch-response")
  const finish = (event) => {
    const ours = event.type === "turbo:visit" || event.type === "turbo:load" || event.target === visit.target
    if (!ours) return
    if (event.type === "turbo:before-fetch-response" && event.detail.fetchResponse.isHTML) return
    events.forEach((name) => document.removeEventListener(name, finish))
    if (event.type === loadEvent) toast(message)
  }
  events.forEach((name) => document.addEventListener(name, finish))
}

export default class extends Controller {
  static values = { url: String }

  connect() {
    // True between IME compositionstart/compositionend. While set, input
    // events carry unconfirmed text — saving it would persist a
    // half-converted fragment (and auto-title from it).
    this.composing = false
    this.field = this.element.getAttribute("name")?.match(/\[(.*)\]/)?.[1]
    this.queue = queueForNote(this.urlValue, this.element.closest("[data-note-lock-version]")?.dataset.noteLockVersion)
    this.deferredValue = null
    if (this.isTitle) {
      this.lastServerValue = this.element.value
      this.recordTitle()
    }
  }

  get isTitle() {
    return this.field === "title"
  }

  compositionstart() {
    this.composing = true
    if (this.field) this.queue.postpone(this.field)
  }

  compositionend() {
    this.composing = false
    this.save()
  }

  save(event) {
    // Input events fired mid-composition (Chrome fires one per keystroke
    // before the conversion is confirmed) must not start the debounce.
    if (this.composing || event?.isComposing || !this.field) return

    const value = this.element.value
    if (this.isTitle) this.recordTitle()
    this.queue.schedule(this.field, value).then((outcome) => this.settle(outcome, value))
  }

  settle(outcome, value) {
    if (outcome === "superseded") return

    if (outcome === "saved" && this.isTitle) this.lastServerValue = value
    if (outcome === "conflict") this.routeConflict()
    else if (outcome === "failed") toast(t("autosave.save_failed"))
    this.element.dispatchEvent(new CustomEvent("autosave:settled", { bubbles: true, detail: { ok: outcome === "saved" } }))
  }

  routeConflict() {
    const queue = this.queue
    const route = conflictRoute({ wrapperConnected: queue.wrapperConnected, visitPaused: pausedVisit !== null, title: queue.title, placeholder: queue.placeholder })
    if (route.discard) queue.discard()

    const message = t("autosave.changed_elsewhere", { title: route.title })
    if (route.action === "toast_now") {
      toast(message)
    } else if (route.action === "toast_after_load") {
      toastAfterVisit(message, pausedVisit)
    } else {
      const target = this.element.isConnected ? this.element : queue.wrapper
      target.dispatchEvent(new CustomEvent("note:conflict", { bubbles: true }))
    }
  }

  serverValue(event) {
    this.syncTitle(event.detail.value, event.detail.noteUrl)
  }

  blur() {
    if (this.deferredValue !== null) this.syncTitle(this.deferredValue, this.urlValue)
  }

  syncTitle(incoming, noteUrl) {
    const decision = titleSyncDecision({
      ownUrl: this.urlValue,
      noteUrl,
      incoming,
      current: this.element.value,
      lastServerValue: this.lastServerValue,
      composing: this.composing,
      titleSaveActive: this.queue.isActive(this.field),
      focused: document.activeElement === this.element
    })
    if (decision === "ignore") return

    this.deferredValue = decision === "defer" ? incoming : null
    if (decision === "apply") this.element.value = incoming
    if (decision === "apply" || decision === "noop") {
      this.lastServerValue = incoming
      this.recordTitle()
    }
  }

  recordTitle() {
    this.queue.title = this.element.value
    this.queue.placeholder = this.element.placeholder
  }
}
