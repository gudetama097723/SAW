import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = { guaranteedPoints: Number }

  fillLowFirst(event) {
    this.allocate(event, this.inputTargets)
  }

  fillHighFirst(event) {
    this.allocate(event, [...this.inputTargets].reverse())
  }

  allocate(event, orderedInputs) {
    event.preventDefault()

    this.inputTargets.forEach((input) => {
      input.value = 0
    })

    let remainingPoints = this.guaranteedPointsValue
    orderedInputs.forEach((input) => {
      if (remainingPoints <= 0) return

      const pointsPerItem = Number(input.dataset.materialPoints)
      const owned = Number(input.max)
      if (pointsPerItem <= 0 || owned <= 0) return

      const quantity = Math.min(owned, Math.ceil(remainingPoints / pointsPerItem))
      input.value = quantity
      remainingPoints -= quantity * pointsPerItem
    })

    this.element.requestSubmit()
  }
}
