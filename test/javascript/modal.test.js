import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { hideModal, installModalHideQueue, showModal } from "../../app/javascript/lib/modal.js"

function fakeElement() {
  const handlers = {}
  return {
    addEventListener: (name, fn) => {
      (handlers[name] ??= []).push(fn)
    },
    fire: (name) => handlers[name]?.forEach((fn) => fn()),
  }
}

function fakeModal() {
  return {
    hides: 0,
    shows: 0,
    hide() {
      this.hides += 1
    },
    show() {
      this.shows += 1
    },
  }
}

describe("hideModal", () => {
  it("hides immediately when settled, and a later show does not re-hide", () => {
    const element = fakeElement()
    const modal = fakeModal()
    const state = installModalHideQueue(element, () => modal)

    hideModal(state, modal)
    element.fire("hidden.bs.modal")
    showModal(state, modal)
    element.fire("shown.bs.modal")

    assert.equal(modal.hides, 1)
    assert.equal(modal.shows, 1)
  })

  it("re-hides once the in-flight show completes", () => {
    const element = fakeElement()
    const modal = fakeModal()
    const state = installModalHideQueue(element, () => modal)

    hideModal(state, modal)
    element.fire("shown.bs.modal")

    assert.equal(modal.hides, 2)
  })

  it("a hide against an already-closed modal never fires on a later open", () => {
    const element = fakeElement()
    const modal = fakeModal()
    const state = installModalHideQueue(element, () => modal)

    // Bootstrap's hide() returns early here, so no hidden event follows.
    hideModal(state, modal)
    element.fire("show.bs.modal")
    element.fire("shown.bs.modal")

    assert.equal(modal.hides, 1)
  })
})
