import { Controller } from "@hotwired/stimulus"

// Constants for tree layout
const NODE_WIDTH = 240
const NODE_HEIGHT = 170
const HORIZONTAL_GAP = 56
const VERTICAL_GAP = 96
const PADDING = 48
const SVG_NS = "http://www.w3.org/2000/svg"

// Zoom limits
const MIN_ZOOM = 0.3
const MAX_ZOOM = 3.0
const ZOOM_STEP = 0.15

export default class extends Controller {
  static targets = ["svg", "nodeTemplates", "goalModal"]
  static values = { roles: Array }

  connect() {
    this.zoom = 1
    this.panX = 0
    this.panY = 0
    this.isPanning = false
    this.lastPointer = null
    this.contentWidth = 0
    this.contentHeight = 0
    this.initialPinchDistance = null

    this.render()
    this.initPanZoom()
  }

  disconnect() {
    this.removePanZoomListeners()
  }

  render() {
    const svg = this.svgTarget
    // Clear existing content
    while (svg.firstChild) {
      svg.removeChild(svg.firstChild)
    }

    const roots = this.rolesValue
    if (!roots || roots.length === 0) return

    const layout = this.calculateLayout(roots)

    this.contentWidth = layout.width
    this.contentHeight = layout.height

    svg.setAttribute("width", "100%")
    svg.setAttribute("height", "100%")
    this.updateViewBox()

    // Draw connections first (behind nodes)
    layout.connections.forEach(conn => this.drawConnection(svg, conn))

    // Draw nodes on top, with add-role buttons
    layout.nodes.forEach(node => {
      const foreignObject = this.drawNode(svg, node)
      this.drawAddButtons(svg, node, foreignObject)
    })
  }

  calculateLayout(roots) {
    // Bottom-up pass: calculate subtree widths
    const calcSubtreeWidth = (node) => {
      if (!node.children || node.children.length === 0) {
        node._subtreeWidth = NODE_WIDTH
      } else {
        const childrenWidth = node.children.reduce((sum, child) => {
          return sum + calcSubtreeWidth(child)
        }, 0) + (node.children.length - 1) * HORIZONTAL_GAP
        node._subtreeWidth = Math.max(NODE_WIDTH, childrenWidth)
      }
      return node._subtreeWidth
    }

    roots.forEach(root => calcSubtreeWidth(root))

    const nodes = []
    const connections = []

    // Top-down pass: assign x, y positions
    const assignPositions = (node, x, y) => {
      // Center the node above its subtree
      const nodeX = x + (node._subtreeWidth - NODE_WIDTH) / 2
      const nodeY = y

      nodes.push({
        id: node.id,
        x: nodeX,
        y: nodeY,
        width: NODE_WIDTH,
        height: NODE_HEIGHT,
        title: node.title,
        description: node.description,
        url: node.url,
        status: node.status,
        parent_id: node.parent_id,
        adapter_type: node.adapter_type,
        working_directory: node.working_directory,
        role_category_id: node.role_category_id
      })

      if (node.children && node.children.length > 0) {
        const parentCenterX = nodeX + NODE_WIDTH / 2
        const parentBottomY = nodeY + NODE_HEIGHT

        let childX = x
        node.children.forEach(child => {
          const childNodeX = childX + (child._subtreeWidth - NODE_WIDTH) / 2
          const childTopY = y + NODE_HEIGHT + VERTICAL_GAP
          const childCenterX = childNodeX + NODE_WIDTH / 2

          connections.push({
            x1: parentCenterX,
            y1: parentBottomY,
            x2: childCenterX,
            y2: childTopY
          })

          assignPositions(child, childX, childTopY)
          childX += child._subtreeWidth + HORIZONTAL_GAP
        })
      }
    }

    // Lay out multiple roots side by side
    let rootX = PADDING
    roots.forEach(root => {
      assignPositions(root, rootX, PADDING)
      rootX += root._subtreeWidth + HORIZONTAL_GAP
    })

    // Calculate total dimensions
    const totalWidth = rootX - HORIZONTAL_GAP + PADDING
    const maxY = nodes.reduce((max, node) => Math.max(max, node.y + node.height), 0)
    const totalHeight = maxY + PADDING

    return { nodes, connections, width: totalWidth, height: totalHeight }
  }

  drawConnection(svg, conn) {
    const path = document.createElementNS(SVG_NS, "path")
    const midY = (conn.y1 + conn.y2) / 2
    path.setAttribute("d", `M ${conn.x1} ${conn.y1} C ${conn.x1} ${midY}, ${conn.x2} ${midY}, ${conn.x2} ${conn.y2}`)
    path.setAttribute("class", "org-chart-line")
    path.setAttribute("fill", "none")
    svg.appendChild(path)
  }

  drawNode(svg, node) {
    const foreignObject = document.createElementNS(SVG_NS, "foreignObject")
    foreignObject.setAttribute("x", node.x)
    foreignObject.setAttribute("y", node.y)
    foreignObject.setAttribute("width", node.width)
    foreignObject.setAttribute("height", node.height)

    // Try to use server-rendered template
    const template = this.findNodeTemplate(node.id)
    if (template) {
      const clone = template.content.cloneNode(true)
      foreignObject.appendChild(clone)
    } else {
      foreignObject.appendChild(this.buildNodeFallback(node))
    }

    svg.appendChild(foreignObject)
    return foreignObject
  }

  findNodeTemplate(roleId) {
    if (!this.hasNodeTemplatesTarget) return null
    return this.nodeTemplatesTarget.querySelector(`template[data-role-id="${roleId}"]`)
  }

  buildNodeFallback(node) {
    const wrapper = document.createElement("div")
    wrapper.className = `org-chart-node-card org-chart-node-card--${node.status || "idle"}`

    const meta = document.createElement("div")
    meta.className = "org-chart-node-card__meta"

    const heading = document.createElement("div")
    heading.className = "org-chart-node-card__heading"

    const link = document.createElement("a")
    link.href = node.url
    link.className = "org-chart-node-card__title"
    link.dataset.turboFrame = "_top"
    link.textContent = node.title
    heading.appendChild(link)

    const dot = document.createElement("span")
    dot.className = "org-chart-node-card__dot"
    heading.appendChild(dot)

    meta.appendChild(heading)

    const tags = document.createElement("div")
    tags.className = "org-chart-node-card__tags"
    const statusSpan = document.createElement("span")
    statusSpan.className = "org-chart-node-card__status"
    statusSpan.textContent = (node.status || "idle").toUpperCase()
    tags.appendChild(statusSpan)
    meta.appendChild(tags)

    wrapper.appendChild(meta)
    return wrapper
  }

  // --- Add-role buttons ---

  drawAddButtons(svg, node, foreignObject) {
    const centerX = node.x + NODE_WIDTH / 2
    const btnRadius = 12

    const btnGroup = document.createElementNS(SVG_NS, "g")
    btnGroup.setAttribute("class", "org-chart-add-btn-group")

    // Top button — add parent
    const topUrl = this.buildNewRoleUrl({
      "role[parent_id]": node.parent_id || "",
      "role[adapter_type]": node.adapter_type,
      "role[working_directory]": node.working_directory,
      "role[role_category_id]": node.role_category_id,
      "reparent_child_id": node.id
    })
    this.appendButtonLink(btnGroup, topUrl, centerX, node.y - btnRadius / 2, btnRadius)

    // Bottom button — add child
    const bottomUrl = this.buildNewRoleUrl({
      "role[parent_id]": node.id,
      "role[adapter_type]": node.adapter_type,
      "role[working_directory]": node.working_directory
    })
    this.appendButtonLink(btnGroup, bottomUrl, centerX, node.y + NODE_HEIGHT + btnRadius / 2, btnRadius)

    svg.appendChild(btnGroup)

    // Hover show/hide
    foreignObject.addEventListener("mouseenter", () => {
      btnGroup.classList.add("org-chart-add-btn-group--visible")
    })
    foreignObject.addEventListener("mouseleave", (e) => {
      if (btnGroup.contains(e.relatedTarget)) return
      btnGroup.classList.remove("org-chart-add-btn-group--visible")
    })
    btnGroup.addEventListener("mouseenter", () => {
      btnGroup.classList.add("org-chart-add-btn-group--visible")
    })
    btnGroup.addEventListener("mouseleave", () => {
      btnGroup.classList.remove("org-chart-add-btn-group--visible")
    })
  }

  appendButtonLink(parent, href, cx, cy, r) {
    const group = document.createElementNS(SVG_NS, "g")
    group.setAttribute("class", "org-chart-add-btn")

    const circle = document.createElementNS(SVG_NS, "circle")
    circle.setAttribute("cx", cx)
    circle.setAttribute("cy", cy)
    circle.setAttribute("r", r)

    const text = document.createElementNS(SVG_NS, "text")
    text.setAttribute("x", cx)
    text.setAttribute("y", cy)
    text.textContent = "+"

    group.appendChild(circle)
    group.appendChild(text)
    group.addEventListener("click", (e) => {
      e.preventDefault()
      e.stopPropagation()
      window.Turbo.visit(href)
    })
    parent.appendChild(group)
  }

  buildNewRoleUrl(params) {
    const url = new URL("/roles/new", window.location.origin)
    for (const [key, value] of Object.entries(params)) {
      if (value != null && value !== "") {
        url.searchParams.set(key, value)
      }
    }
    return url.toString()
  }

  // --- Pan & Zoom ---

  initPanZoom() {
    const svg = this.svgTarget

    this._onWheel = this.onWheel.bind(this)
    this._onPointerDown = this.onPointerDown.bind(this)
    this._onPointerMove = this.onPointerMove.bind(this)
    this._onPointerUp = this.onPointerUp.bind(this)
    this._onTouchStart = this.onTouchStart.bind(this)
    this._onTouchMove = this.onTouchMove.bind(this)
    this._onTouchEnd = this.onTouchEnd.bind(this)

    svg.addEventListener("wheel", this._onWheel, { passive: false })
    svg.addEventListener("pointerdown", this._onPointerDown)
    svg.addEventListener("pointermove", this._onPointerMove)
    svg.addEventListener("pointerup", this._onPointerUp)
    svg.addEventListener("pointercancel", this._onPointerUp)
    svg.addEventListener("touchstart", this._onTouchStart, { passive: false })
    svg.addEventListener("touchmove", this._onTouchMove, { passive: false })
    svg.addEventListener("touchend", this._onTouchEnd)
  }

  removePanZoomListeners() {
    const svg = this.svgTarget

    svg.removeEventListener("wheel", this._onWheel)
    svg.removeEventListener("pointerdown", this._onPointerDown)
    svg.removeEventListener("pointermove", this._onPointerMove)
    svg.removeEventListener("pointerup", this._onPointerUp)
    svg.removeEventListener("pointercancel", this._onPointerUp)
    svg.removeEventListener("touchstart", this._onTouchStart)
    svg.removeEventListener("touchmove", this._onTouchMove)
    svg.removeEventListener("touchend", this._onTouchEnd)
  }

  onWheel(e) {
    e.preventDefault()

    const rect = this.svgTarget.getBoundingClientRect()
    const cursorX = e.clientX - rect.left
    const cursorY = e.clientY - rect.top

    const delta = e.deltaY > 0 ? -ZOOM_STEP : ZOOM_STEP
    this.zoomAtPoint(delta, cursorX, cursorY, rect.width, rect.height)
  }

  onPointerDown(e) {
    // Only pan with left button on SVG background (not on nodes)
    if (e.button !== 0) return
    if (this.isNodeElement(e.target)) return

    this.isPanning = true
    this.lastPointer = { x: e.clientX, y: e.clientY }
    this.svgTarget.setPointerCapture(e.pointerId)
    this.element.classList.add("org-chart-container--panning")
  }

  onPointerMove(e) {
    if (!this.isPanning || !this.lastPointer) return

    const rect = this.svgTarget.getBoundingClientRect()
    const viewWidth = this.contentWidth / this.zoom
    const viewHeight = this.contentHeight / this.zoom

    // Convert pixel delta to SVG coordinate delta
    const dx = (e.clientX - this.lastPointer.x) * (viewWidth / rect.width)
    const dy = (e.clientY - this.lastPointer.y) * (viewHeight / rect.height)

    this.panX -= dx
    this.panY -= dy
    this.lastPointer = { x: e.clientX, y: e.clientY }
    this.updateViewBox()
  }

  onPointerUp(e) {
    if (!this.isPanning) return

    this.isPanning = false
    this.lastPointer = null
    this.svgTarget.releasePointerCapture(e.pointerId)
    this.element.classList.remove("org-chart-container--panning")
  }

  onTouchStart(e) {
    if (e.touches.length === 2) {
      e.preventDefault()
      this.initialPinchDistance = this.getTouchDistance(e.touches)
    }
  }

  onTouchMove(e) {
    if (e.touches.length === 2 && this.initialPinchDistance) {
      e.preventDefault()
      const currentDistance = this.getTouchDistance(e.touches)
      const scale = currentDistance / this.initialPinchDistance

      const rect = this.svgTarget.getBoundingClientRect()
      const centerX = rect.width / 2
      const centerY = rect.height / 2

      const delta = (scale - 1) * 0.5
      this.zoomAtPoint(delta, centerX, centerY, rect.width, rect.height)
      this.initialPinchDistance = currentDistance
    }
  }

  onTouchEnd() {
    this.initialPinchDistance = null
  }

  getTouchDistance(touches) {
    const dx = touches[0].clientX - touches[1].clientX
    const dy = touches[0].clientY - touches[1].clientY
    return Math.sqrt(dx * dx + dy * dy)
  }

  zoomAtPoint(delta, cursorX, cursorY, containerWidth, containerHeight) {
    const oldZoom = this.zoom
    this.zoom = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, this.zoom + delta))

    if (this.zoom === oldZoom) return

    // Adjust pan so the point under the cursor stays fixed
    const viewWidthOld = this.contentWidth / oldZoom
    const viewHeightOld = this.contentHeight / oldZoom
    const viewWidthNew = this.contentWidth / this.zoom
    const viewHeightNew = this.contentHeight / this.zoom

    const cursorFractionX = cursorX / containerWidth
    const cursorFractionY = cursorY / containerHeight

    this.panX += (viewWidthOld - viewWidthNew) * cursorFractionX
    this.panY += (viewHeightOld - viewHeightNew) * cursorFractionY

    this.updateViewBox()
  }

  updateViewBox() {
    const viewWidth = this.contentWidth / this.zoom
    const viewHeight = this.contentHeight / this.zoom
    this.svgTarget.setAttribute("viewBox", `${this.panX} ${this.panY} ${viewWidth} ${viewHeight}`)
  }

  isNodeElement(el) {
    let current = el
    while (current && current !== this.svgTarget) {
      if (current.tagName === "foreignObject" || current.tagName === "foreignobject") return true
      if (current.classList && current.classList.contains("org-chart-add-btn-group")) return true
      current = current.parentElement || current.parentNode
    }
    return false
  }

  // --- Toolbar actions ---

  zoomIn() {
    const rect = this.svgTarget.getBoundingClientRect()
    this.zoomAtPoint(ZOOM_STEP, rect.width / 2, rect.height / 2, rect.width, rect.height)
  }

  zoomOut() {
    const rect = this.svgTarget.getBoundingClientRect()
    this.zoomAtPoint(-ZOOM_STEP, rect.width / 2, rect.height / 2, rect.width, rect.height)
  }

  zoomReset() {
    this.zoom = 1
    this.panX = 0
    this.panY = 0
    this.updateViewBox()
  }

  // --- Goal modal ---

  openGoalModal(e) {
    e.preventDefault()
    const roleId = e.currentTarget.dataset.roleId
    const wrapper = this.goalModalTargets.find(el => el.dataset.roleId === roleId)
    const dialog = wrapper?.querySelector("dialog")
    if (!dialog) return

    const modalController = this.application.getControllerForElementAndIdentifier(dialog, "modal")
    modalController?.open()
  }
}
