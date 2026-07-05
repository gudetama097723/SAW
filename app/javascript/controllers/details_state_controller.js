import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.details = Array.from(this.element.querySelectorAll("details[data-details-state-key]"))

    this.details.forEach((detail) => {
      const key = detail.dataset.detailsStateKey
      const saved = detail.dataset.detailsStateLocked === "true" ? null : this.read(key)

      if (saved === "open") {
        detail.open = true
      } else if (saved === "closed") {
        detail.open = false
      }

      detail.addEventListener("toggle", this.store)
    })
  }

  disconnect() {
    this.details?.forEach((detail) => detail.removeEventListener("toggle", this.store))
  }

  store = (event) => {
    const detail = event.currentTarget
    if (detail.dataset.detailsStateLocked === "true") return

    this.write(detail.dataset.detailsStateKey, detail.open ? "open" : "closed")
  }

  read(key) {
    try {
      return window.localStorage.getItem(this.storageKey(key))
    } catch {
      return null
    }
  }

  write(key, value) {
    try {
      window.localStorage.setItem(this.storageKey(key), value)
    } catch {
      // Ignore storage errors so the UI still works in restricted browser modes.
    }
  }

  storageKey(key) {
    return `saw:details:${key}`
  }
}
