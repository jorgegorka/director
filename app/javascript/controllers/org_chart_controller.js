import { Controller } from "@hotwired/stimulus"

// Constants for tree layout
const NODE_WIDTH = 220
const NODE_HEIGHT = 100
const HORIZONTAL_GAP = 40
const VERTICAL_GAP = 80
const PADDING = 40

export default class extends Controller {
  static targets = ["svg"]
  static values = { roles: Array }

  connect() {
    this.render()
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

    svg.setAttribute("width", layout.width)
    svg.setAttribute("height", layout.height)
    svg.setAttribute("viewBox", `0 0 ${layout.width} ${layout.height}`)

    // Draw connections first (behind nodes)
    layout.connections.forEach(conn => this.drawConnection(svg, conn))

    // Draw nodes on top
    layout.nodes.forEach(node => this.drawNode(svg, node))
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
        x: nodeX,
        y: nodeY,
        width: NODE_WIDTH,
        height: NODE_HEIGHT,
        title: node.title,
        description: node.description,
        url: node.url,
        agentName: node.agent_name
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
    const NS = "http://www.w3.org/2000/svg"
    const path = document.createElementNS(NS, "path")
    const midY = (conn.y1 + conn.y2) / 2
    path.setAttribute("d", `M ${conn.x1} ${conn.y1} C ${conn.x1} ${midY}, ${conn.x2} ${midY}, ${conn.x2} ${conn.y2}`)
    path.setAttribute("class", "org-chart-line")
    path.setAttribute("fill", "none")
    svg.appendChild(path)
  }

  drawNode(svg, node) {
    const NS = "http://www.w3.org/2000/svg"

    const foreignObject = document.createElementNS(NS, "foreignObject")
    foreignObject.setAttribute("x", node.x)
    foreignObject.setAttribute("y", node.y)
    foreignObject.setAttribute("width", node.width)
    foreignObject.setAttribute("height", node.height)

    // Wrapper div
    const wrapper = document.createElement("div")
    wrapper.className = "org-chart-node"

    // Link element
    const link = document.createElement("a")
    link.href = node.url
    link.className = "org-chart-node__link"
    link.dataset.turboFrame = "_top"

    // Title
    const titleSpan = document.createElement("span")
    titleSpan.className = "org-chart-node__title"
    titleSpan.textContent = node.title
    link.appendChild(titleSpan)

    // Agent status
    const agentSpan = document.createElement("span")
    agentSpan.className = "org-chart-node__agent"

    const dot = document.createElement("span")
    dot.className = node.agentName
      ? "org-chart-node__dot org-chart-node__dot--active"
      : "org-chart-node__dot org-chart-node__dot--unassigned"
    agentSpan.appendChild(dot)

    const agentText = document.createTextNode(node.agentName || "Unassigned")
    agentSpan.appendChild(agentText)
    link.appendChild(agentSpan)

    // Description (optional)
    if (node.description) {
      const descSpan = document.createElement("span")
      descSpan.className = "org-chart-node__desc"
      descSpan.textContent = node.description
      link.appendChild(descSpan)
    }

    wrapper.appendChild(link)
    foreignObject.appendChild(wrapper)
    svg.appendChild(foreignObject)
  }
}
