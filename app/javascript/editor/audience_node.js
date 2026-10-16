import * as Lexxy from "lexxy"

const {
  ElementNode,
  $applyNodeReplacement,
  $createParagraphNode
} = Lexxy.Lexical

const AUDIENCES = [ "web", "email" ]

// A box kept for one audience is stored as:
//
//   <aside data-audience="web">
//     <p>Subscribe on the site.</p>
//   </aside>
//
// Lexical only keeps elements it has a node for, so without this class it unwraps the <aside>
// and the box is gone the next time the post is saved. Modelled on Pagecord's callout.
export class AudienceNode extends ElementNode {
  __audience

  static getType() {
    return "audience"
  }

  static clone(node) {
    return new AudienceNode(node.__audience, node.__key)
  }

  // Null for an <aside> that is no box declines the conversion, so anything else keeps the handling it had.
  static importDOM() {
    return {
      aside: (element) => AUDIENCES.includes(element.getAttribute("data-audience")) ? { conversion: convertAudienceElement, priority: 1 } : null
    }
  }

  static importJSON(serializedNode) {
    return $createAudienceNode(serializedNode.audience).updateFromJSON(serializedNode)
  }

  constructor(audience = AUDIENCES[0], key) {
    super(key)
    this.__audience = audience
  }

  // A boundary, as a table cell is: a list or a divider asked for inside the box is made inside it.
  isShadowRoot() {
    return true
  }

  // exportDOM is inherited and calls this, so one method covers the editor and the saved text.
  createDOM() {
    const element = document.createElement("aside")
    element.setAttribute("data-audience", this.__audience)
    return element
  }

  updateDOM(prevNode, element) {
    if (prevNode.__audience !== this.__audience) {
      element.setAttribute("data-audience", this.__audience)
    }

    return false
  }

  exportJSON() {
    return { ...super.exportJSON(), audience: this.getAudience() }
  }

  getAudience() {
    return this.getLatest().__audience
  }
}

function convertAudienceElement(element) {
  return { node: $createAudienceNode(element.getAttribute("data-audience")) }
}

export function $createAudienceNode(audience) {
  return $applyNodeReplacement(new AudienceNode(audience))
}

export function $isAudienceNode(node) {
  return node instanceof AudienceNode
}

// A box always has a line to write on.
export function $ensureLineIn(audience) {
  if (audience.isEmpty()) audience.append($createParagraphNode())
}

// Lifts what the box holds back out, and the box is gone.
export function $unwrapAudience(audience) {
  audience.getChildren().forEach((child) => audience.insertBefore(child))
  audience.remove()
}
