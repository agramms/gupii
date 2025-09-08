import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "calendar", "startDate", "endDate", "monthYear", "calendarGrid", "applyButton"]
  static values = { fieldPrefix: String }

  connect() {
    this.currentDate = new Date()
    this.startDate = null
    this.endDate = null
    this.selectingEndDate = false
    
    // Set initial dates from hidden inputs if they exist
    if (this.startDateTarget.value) {
      this.startDate = new Date(this.startDateTarget.value)
    }
    if (this.endDateTarget.value) {
      this.endDate = new Date(this.endDateTarget.value)
    }
    
    // Update display value on connect
    this.updateDisplayValue()
    this.renderCalendar()
    this.updateApplyButton()
    this.setupOutsideClick()
  }

  disconnect() {
    if (this.outsideClickHandler) {
      document.removeEventListener('click', this.outsideClickHandler)
    }
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (this.calendarTarget.classList.contains('hidden')) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.calendarTarget.classList.remove('hidden')
    this.element.setAttribute('aria-expanded', 'true')
    this.renderCalendar()
  }

  close() {
    this.calendarTarget.classList.add('hidden')
    this.element.setAttribute('aria-expanded', 'false')
    this.selectingEndDate = false
  }

  preventClose(event) {
    event.stopPropagation()
  }

  cancel() {
    this.close()
  }

  clear() {
    this.startDate = null
    this.endDate = null
    this.startDateTarget.value = ''
    this.endDateTarget.value = ''
    this.displayTarget.value = ''
    this.selectingEndDate = false
    this.renderCalendar()
    this.updateApplyButton()
    this.close()
    
    // Trigger form submission to update filters
    this.element.closest('form')?.requestSubmit()
  }

  apply() {
    if (this.startDate && this.endDate) {
      this.startDateTarget.value = this.formatForBackend(this.startDate)
      this.endDateTarget.value = this.formatForBackend(this.endDate)
      this.displayTarget.value = this.formatRangeDisplay(this.startDate, this.endDate)
      this.close()
      
      // Trigger form submission to update filters
      this.element.closest('form')?.requestSubmit()
    }
  }

  previousMonth() {
    this.currentDate.setMonth(this.currentDate.getMonth() - 1)
    this.renderCalendar()
  }

  nextMonth() {
    this.currentDate.setMonth(this.currentDate.getMonth() + 1)
    this.renderCalendar()
  }

  selectDate(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const dateStr = event.currentTarget.dataset.date
    const selectedDate = new Date(dateStr)
    
    if (!this.startDate || this.selectingEndDate) {
      // First click or selecting end date
      if (!this.startDate) {
        // First date selection
        this.startDate = selectedDate
        this.endDate = null
        this.selectingEndDate = true
      } else if (selectedDate >= this.startDate) {
        // Valid end date
        this.endDate = selectedDate
        this.selectingEndDate = false
      } else {
        // Selected date is before start date, reset
        this.startDate = selectedDate
        this.endDate = null
        this.selectingEndDate = true
      }
    } else {
      // Start date is set, now setting end date
      if (selectedDate >= this.startDate) {
        this.endDate = selectedDate
        this.selectingEndDate = false
      } else {
        // Reset if end date is before start date
        this.startDate = selectedDate
        this.endDate = null
        this.selectingEndDate = true
      }
    }
    
    // Update display immediately for better UX
    this.updateDisplayValue()
    this.renderCalendar()
    this.updateApplyButton()
  }

  renderCalendar() {
    // Update month/year display
    this.monthYearTarget.textContent = this.formatMonthYear(this.currentDate)
    
    // Clear calendar grid
    this.calendarGridTarget.innerHTML = ''
    
    // Get first day of month and number of days
    const firstDay = new Date(this.currentDate.getFullYear(), this.currentDate.getMonth(), 1)
    const lastDay = new Date(this.currentDate.getFullYear(), this.currentDate.getMonth() + 1, 0)
    const daysInMonth = lastDay.getDate()
    const startDay = firstDay.getDay() // 0 = Sunday
    
    // Add empty cells for days before the first day of the month
    for (let i = 0; i < startDay; i++) {
      const emptyDay = document.createElement('div')
      emptyDay.className = 'w-8 h-8'
      this.calendarGridTarget.appendChild(emptyDay)
    }
    
    // Add days of the month
    for (let day = 1; day <= daysInMonth; day++) {
      const date = new Date(this.currentDate.getFullYear(), this.currentDate.getMonth(), day)
      const dayButton = this.createDayButton(date, day)
      this.calendarGridTarget.appendChild(dayButton)
    }
  }

  createDayButton(date, day) {
    const button = document.createElement('button')
    button.type = 'button'
    button.className = 'w-8 h-8 text-sm rounded-full transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-1'
    button.textContent = day
    button.dataset.date = date.toISOString().split('T')[0]
    button.dataset.action = 'click->daterange#selectDate'
    
    // Styling based on selection state
    if (this.isDateInRange(date)) {
      button.className += ' bg-indigo-100 text-indigo-900'
    } else if (this.isStartDate(date) || this.isEndDate(date)) {
      button.className += ' bg-indigo-600 text-white hover:bg-indigo-700'
    } else if (this.isToday(date)) {
      button.className += ' bg-gray-100 text-gray-900 hover:bg-gray-200'
    } else {
      button.className += ' text-gray-700 hover:bg-gray-50'
    }
    
    // Disable past dates if needed (optional)
    // if (date < new Date().setHours(0, 0, 0, 0)) {
    //   button.disabled = true
    //   button.className += ' opacity-50 cursor-not-allowed'
    // }
    
    return button
  }

  isStartDate(date) {
    return this.startDate && this.isSameDate(date, this.startDate)
  }

  isEndDate(date) {
    return this.endDate && this.isSameDate(date, this.endDate)
  }

  isDateInRange(date) {
    if (!this.startDate || !this.endDate) return false
    return date > this.startDate && date < this.endDate
  }

  isToday(date) {
    const today = new Date()
    return this.isSameDate(date, today)
  }

  isSameDate(date1, date2) {
    return date1.getFullYear() === date2.getFullYear() &&
           date1.getMonth() === date2.getMonth() &&
           date1.getDate() === date2.getDate()
  }

  updateApplyButton() {
    if (this.startDate && this.endDate) {
      this.applyButtonTarget.disabled = false
      this.applyButtonTarget.textContent = 'Aplicar'
    } else if (this.startDate && this.selectingEndDate) {
      this.applyButtonTarget.disabled = true
      this.applyButtonTarget.textContent = 'Selecione a data final'
    } else {
      this.applyButtonTarget.disabled = true
      this.applyButtonTarget.textContent = 'Selecione as datas'
    }
  }

  updateDisplayValue() {
    if (this.startDate && this.endDate) {
      this.displayTarget.value = this.formatRangeDisplay(this.startDate, this.endDate)
    } else if (this.startDate) {
      const startFormatted = new Intl.DateTimeFormat('pt-BR', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric'
      }).format(this.startDate)
      this.displayTarget.value = `${startFormatted} - Selecione data final`
    } else {
      this.displayTarget.value = ''
    }
  }

  formatMonthYear(date) {
    return new Intl.DateTimeFormat('pt-BR', {
      month: 'long',
      year: 'numeric'
    }).format(date)
  }

  formatForBackend(date) {
    // Format as YYYY-MM-DD for backend
    return date.toISOString().split('T')[0]
  }

  formatRangeDisplay(startDate, endDate) {
    const formatter = new Intl.DateTimeFormat('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    })
    
    if (this.isSameDate(startDate, endDate)) {
      return formatter.format(startDate)
    }
    
    return `${formatter.format(startDate)} - ${formatter.format(endDate)}`
  }

  setupOutsideClick() {
    this.outsideClickHandler = (event) => {
      // Don't close if clicking inside the date range picker element
      if (!this.element.contains(event.target) && 
          !this.calendarTarget.classList.contains('hidden') &&
          !this.calendarTarget.contains(event.target)) {
        this.close()
      }
    }
    document.addEventListener('click', this.outsideClickHandler)
  }

  // Quick preset methods
  setPreset(event) {
    const days = parseInt(event.currentTarget.dataset.days)
    const endDate = new Date()
    const startDate = new Date()
    
    if (days === 0) {
      // Today
      startDate.setHours(0, 0, 0, 0)
      endDate.setHours(23, 59, 59, 999)
    } else {
      // X days ago
      startDate.setDate(startDate.getDate() - days)
      startDate.setHours(0, 0, 0, 0)
      endDate.setHours(23, 59, 59, 999)
    }
    
    this.startDate = startDate
    this.endDate = endDate
    this.selectingEndDate = false
    
    this.startDateTarget.value = this.formatForBackend(startDate)
    this.endDateTarget.value = this.formatForBackend(endDate)
    this.displayTarget.value = this.formatRangeDisplay(startDate, endDate)
    
    this.close()
    this.element.closest('form')?.requestSubmit()
  }
}