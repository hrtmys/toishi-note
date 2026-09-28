// Serializes one note's autosaves: at most one in flight, and each save
// reads the lock version only when it is sent, after the previous response
// updated it. After a 409 every save is held until keepMine() or discard().
export class SaveQueue {
  constructor({ version, send }) {
    this.version = Number(version)
    this.send = send
    this.pending = new Map() // field -> { value, waiters }
    this.inFlight = false
    this.held = false
    this.conflictVersion = null
  }

  get hasUnsaved() {
    return this.inFlight || this.pending.size > 0
  }

  request(field, value) {
    return new Promise((resolve) => {
      const entry = this.pending.get(field)
      if (entry) {
        entry.value = value
        entry.waiters.push(resolve)
      } else {
        this.pending.set(field, { value, waiters: [ resolve ] })
      }
      this.pump()
    })
  }

  // Resubmits the held values over the other device's version.
  keepMine() {
    if (this.conflictVersion !== null) this.adopt(this.conflictVersion)
    this.conflictVersion = null
    this.held = false
    this.pump()
  }

  discard() {
    for (const entry of this.pending.values()) entry.waiters.forEach((resolve) => resolve("discarded"))
    this.pending.clear()
    this.conflictVersion = null
    this.held = false
  }

  adopt(version) {
    if (version !== null && version !== undefined && Number(version) > this.version) this.version = Number(version)
  }

  async pump() {
    if (this.inFlight || this.held || this.pending.size === 0) return

    const [ field, entry ] = this.pending.entries().next().value
    this.pending.delete(field)
    this.inFlight = true

    let outcome
    try {
      const { status, version } = await this.send({ field, value: entry.value, version: this.version })
      if (status === 409) {
        outcome = "conflict"
        this.held = true
        this.conflictVersion = version
        // The conflicted value is still unsaved; keep it for keepMine()
        // unless a newer value for the same field is already waiting.
        if (!this.pending.has(field)) this.pending.set(field, { value: entry.value, waiters: [] })
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
    entry.waiters.forEach((resolve) => resolve(outcome))
    this.pump()
  }
}
