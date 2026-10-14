// Drawing a mark on a page's canvas, in page units (see marks/_mark.html.erb).

const SVG = "http://www.w3.org/2000/svg"

export function draw(canvas, { kind, color, points, text }) {
  let element

  if (kind === "word") {
    element = document.createElementNS(SVG, "text")
    element.setAttribute("x", points[0][0])
    element.setAttribute("y", points[0][1])
    element.setAttribute("dominant-baseline", "central")
    element.textContent = text
  } else {
    element = document.createElementNS(SVG, "path")
    element.setAttribute("d", pathData(points))
  }

  element.setAttribute("class", `mark mark--${kind} mark--${color}`)
  canvas.append(element)
  return element
}

export function pathData(points) {
  return points.map(([ x, y ], index) => `${index ? "L" : "M"}${x} ${y}`).join(" ")
}
