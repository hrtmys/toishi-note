// Bootstrap's hide() is a silent no-op mid-show-transition, stranding the
// modal open. Queue the request instead: hide now if settled, else once
// the in-flight show completes. show()/hidden always clear the queue.
export function installModalHideQueue(element, getModal) {
  const state = { hideQueued: false }

  element.addEventListener("shown.bs.modal", () => {
    if (state.hideQueued) {
      state.hideQueued = false
      getModal().hide()
    }
  })
  // hide() on an already-closed modal returns early without hidden, so a
  // queued hide can outlive its modal. Every open fires show first.
  element.addEventListener("show.bs.modal", () => {
    state.hideQueued = false
  })
  element.addEventListener("hidden.bs.modal", () => {
    state.hideQueued = false
  })

  return state
}

export function showModal(state, modal) {
  state.hideQueued = false
  modal.show()
}

export function hideModal(state, modal) {
  state.hideQueued = true
  modal.hide()
}
