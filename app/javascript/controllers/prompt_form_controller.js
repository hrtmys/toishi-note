import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  
  submit(event) {
    event.preventDefault()
    
    const message = this.element.dataset.promptMessage
    // Pre-fill the prompt with the current value, if any.
    const initialValue = this.inputTarget.value || ""
    const name = prompt(message, initialValue)
    
    if (name && name.trim() !== "") {
      this.inputTarget.value = name.trim()
      this.element.submit()
    }
  }
}