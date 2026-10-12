const DEBOUNCE_MS = 500

// Keyed by note path, so every page instance of a note in this tab (fresh,
// restored from a snapshot, or previewed) shares one queue and one version.
const noteQueues = new Map()

export function noteQueue(noteUrl, options) {
  let queue = noteQueues.get(noteUrl)
  if (!queue) {
    queue = new SaveQueue(options)
    noteQueues.set(noteUrl, queue)
  }
  return queue
}

export function findNoteQueue(noteUrl) {
  return noteQueues.get(noteUrl)
}

export function allNoteQueues() {
  return Array.from(noteQueues.values())
}

// Serializes one note's autosaves: at most one in flight, and each save
// reads the lock version only when it is sent, after the previous response
// updated it. A hold blocks values sequenced after it until keepMine() or discard().
export class SaveQueue {
  constructor({ version, send, onChange }) {
    this.version = Number(version)
    this.send = send
    this.onChange = onChange
    this.scheduled = new Map() // field -> { value, seq, waiters, timer }
    this.pending = new Map() // field -> { value, seq, waiters }
    this.inFlight = false
    this.inFlightField = null
    this.held = false
    this.holdReason = null
    this.holdSeq = 0
    this.conflictVersion = null
    this.wrapper = null
    this.wrapperConnected = false
    this.seq = 0
    this.settledSeq = new Map()
    this.waits = []
  }

  get hasUnsaved() {
    return this.inFlight || this.pending.size > 0 || this.scheduled.size > 0
  }

  isActive(field) {
    return this.scheduled.has(field) || this.pending.has(field) || this.inFlightField === field
  }

  schedule(field, value) {
    return new Promise((resolve) => {
      this.cancelScheduled(field)
      const entry = { value, seq: ++this.seq, waiters: [ resolve ] }
      entry.timer = setTimeout(() => this.ready(field), DEBOUNCE_MS)
      this.scheduled.set(field, entry)
      this.changed()
    })
  }

  request(field, value) {
    return new Promise((resolve) => {
      this.cancelScheduled(field)
      this.enqueue(field, { value, seq: ++this.seq, waiters: [ resolve ] })
    })
  }

  // Keeps the last confirmed value but stops its timer, e.g. during IME composition.
  postpone(field) {
    clearTimeout(this.scheduled.get(field)?.timer)
  }

  flush() {
    for (const field of Array.from(this.scheduled.keys())) this.ready(field)
  }

  // Resubmits the held values over the other device's version.
  keepMine() {
    if (this.conflictVersion !== null) this.adopt(this.conflictVersion)
    this.conflictVersion = null
    this.held = false
    this.holdReason = null
    for (const entry of this.pending.values()) entry.conflicted = false
    this.changed()
    this.pump()
  }

  discard() {
    for (const entry of this.scheduled.values()) {
      clearTimeout(entry.timer)
      entry.waiters.forEach((resolve) => resolve("discarded"))
    }
    for (const entry of this.pending.values()) entry.waiters.forEach((resolve) => resolve("discarded"))
    this.scheduled.clear()
    this.pending.clear()
    this.conflictVersion = null
    this.held = false
    this.holdReason = null
    this.checkWaits()
    this.changed()
  }

  adopt(version) {
    if (version !== null && version !== undefined && Number(version) > this.version) this.version = Number(version)
  }

  // A snapshot's fields carry the typed text, so its older version is ignored
  // unless values were sequenced after it was taken (e.g. from another URL).
  attach(wrapper, { version, snapshot, snapshotSeq }) {
    if (this.held && wrapper !== this.wrapper) this.dropHeldValues()
    this.wrapper = wrapper
    this.wrapperConnected = true

    let result = null
    const trusted = snapshot ? snapshotSeq !== undefined && snapshotSeq >= this.seq : Number(version) >= this.version
    if (trusted) {
      this.adopt(version)
    } else if (!this.held) {
      this.hold("stale")
      result = "stale"
    }
    this.changed()
    return result
  }

  detach(wrapper) {
    if (this.wrapper !== wrapper) return
    this.wrapperConnected = false
    this.changed()
  }

  // Resolves once every value unsaved at call time has settled (or the queue
  // is held), so values typed meanwhile can't extend the wait.
  waitForPending(capMs) {
    return new Promise((resolve) => {
      if (!this.hasUnsaved || this.held) return resolve()

      const targets = new Map()
      for (const entries of [ this.pending, this.scheduled ]) {
        for (const [ field, entry ] of entries) targets.set(field, Math.max(targets.get(field) ?? 0, entry.seq))
      }
      if (this.inFlight) targets.set(this.inFlightField, Math.max(targets.get(this.inFlightField) ?? 0, this.inFlightSeq))

      const wait = { targets, resolve }
      wait.timer = setTimeout(() => this.endWait(wait), capMs)
      this.waits.push(wait)
    })
  }

  hold(reason) {
    this.held = true
    this.holdReason = reason
    this.holdSeq = this.seq
    this.checkWaits()
  }

  // Values typed before the hold came from an up-to-date page, so only later ones are dropped.
  dropHeldValues() {
    for (const [ field, entry ] of Array.from(this.scheduled)) {
      if (entry.seq <= this.holdSeq) continue
      clearTimeout(entry.timer)
      entry.waiters.forEach((resolve) => resolve("discarded"))
      this.scheduled.delete(field)
    }
    for (const [ field, entry ] of Array.from(this.pending)) {
      if (entry.seq <= this.holdSeq && !entry.conflicted) continue
      entry.waiters.forEach((resolve) => resolve("discarded"))
      this.pending.delete(field)
    }
    this.conflictVersion = null
    this.held = false
    this.holdReason = null
    this.checkWaits()
    this.changed()
    this.pump()
  }

  sendable(entry) {
    return !this.held || (entry.seq <= this.holdSeq && !entry.conflicted)
  }

  cancelScheduled(field) {
    const entry = this.scheduled.get(field)
    if (!entry) return
    clearTimeout(entry.timer)
    entry.waiters.forEach((resolve) => resolve("superseded"))
    this.scheduled.delete(field)
  }

  ready(field) {
    const entry = this.scheduled.get(field)
    if (!entry) return
    this.scheduled.delete(field)
    this.enqueue(field, { value: entry.value, seq: entry.seq, waiters: entry.waiters })
  }

  enqueue(field, { value, seq, waiters }) {
    const entry = this.pending.get(field)
    if (entry) {
      entry.value = value
      entry.seq = seq
      entry.waiters.push(...waiters)
    } else {
      this.pending.set(field, { value, seq, waiters })
    }
    this.changed()
    this.pump()
  }

  checkWaits() {
    for (const wait of Array.from(this.waits)) {
      const settled = Array.from(wait.targets).every(([ field, seq ]) => (this.settledSeq.get(field) ?? 0) >= seq || !this.isActive(field))
      if (this.held || settled) this.endWait(wait)
    }
  }

  endWait(wait) {
    clearTimeout(wait.timer)
    this.waits = this.waits.filter((other) => other !== wait)
    wait.resolve()
  }

  changed() {
    this.onChange?.()
  }

  async pump() {
    if (this.inFlight) return
    const next = Array.from(this.pending).find(([ , entry ]) => this.sendable(entry))
    if (!next) return

    const [ field, entry ] = next
    this.pending.delete(field)
    this.inFlight = true
    this.inFlightField = field
    this.inFlightSeq = entry.seq

    let outcome
    try {
      const { status, version } = await this.send({ field, value: entry.value, version: this.version })
      if (status === 409) {
        outcome = "conflict"
        this.conflictVersion = version
        // The conflicted value is still unsaved; keep it for keepMine()
        // unless a newer value for the same field is already waiting.
        if (!this.pending.has(field)) this.pending.set(field, { value: entry.value, seq: entry.seq, waiters: [] })
        // Values already waiting would carry the same outdated version.
        for (const waiting of this.pending.values()) waiting.conflicted = true
        this.hold("conflict")
      } else if (status >= 200 && status <= 299) {
        outcome = "saved"
        this.adopt(version)
      } else {
        outcome = "failed"
      }
    } catch {
      outcome = "failed"
    }

    this.inFlight = false
    this.inFlightField = null
    this.settledSeq.set(field, Math.max(this.settledSeq.get(field) ?? 0, entry.seq))
    entry.waiters.forEach((resolve) => resolve(outcome))
    this.checkWaits()
    this.changed()
    this.pump()
  }
}
