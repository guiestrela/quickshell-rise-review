// Adapted from omacom/omarchy shell/plugins/panels/elsewhen/Arc.js (MIT).
// Copyright (c) David Heinemeier Hansson; see NOTICE.md for the license text.
// `widths` are glyph advances; `rise` is the end-to-center sagitta.
function layout(widths, rise, smile) {
  var chars = []
  var total = 0
  var i
  for (i = 0; i < widths.length; i++) total += widths[i]

  if (total <= 0 || rise <= 0) {
    var x = 0
    for (i = 0; i < widths.length; i++) {
      chars.push({ x: x, y: 0, rotation: 0 })
      x += widths[i]
    }
    return { width: total, height: 0, chars: chars }
  }

  var sag = Math.min(rise, total / 4)
  var radius = (total * total) / (8 * sag)
  var halfAngle = total / (2 * radius)
  var maxDrop = radius * (1 - Math.cos(halfAngle))
  var chordWidth = 2 * radius * Math.sin(halfAngle)

  var travelled = 0
  var left = 0
  var right = chordWidth
  for (i = 0; i < widths.length; i++) {
    var width = widths[i]
    var angle = (travelled + width / 2 - total / 2) / radius
    var drop = radius * (1 - Math.cos(angle))
    var charX = chordWidth / 2 + radius * Math.sin(angle) - width / 2
    chars.push({
      x: charX,
      y: smile ? maxDrop - drop : drop,
      rotation: (smile ? -angle : angle) * 180 / Math.PI
    })
    left = Math.min(left, charX)
    right = Math.max(right, charX + width)
    travelled += width
  }

  for (i = 0; i < chars.length; i++) chars[i].x -= left
  return { width: right - left, height: maxDrop, chars: chars }
}

if (typeof module !== "undefined") module.exports = { layout: layout }
