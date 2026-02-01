import std/strformat
import std/terminal

import types
import term

proc userSelect*(addon: Addon, options: seq[string]): int {.gcsafe.} =
  let t = addon.config.term
  var selected = 1
  for _ in 0 ..< options.len:
    t.addLine()
  while true:
    for i, option in options:
      if selected == i + 1:
        t.write(13, addon.line + i + 1, bgWhite, fgBlack, &"{i + 1}: {option}", resetStyle)
      else:
        t.write(13, addon.line + i + 1, bgBlack, fgWhite, &"{i + 1}: {option}", resetStyle)
    let newSelected = handleSelection(options.len, selected)
    if newSelected == selected:
      for i, option in options:
        if selected == i + 1:
          t.write(13, addon.line + i + 1, bgBlack, fgGreen, &"{i + 1}: {option}", resetStyle)
        else:
          t.write(13, addon.line + i + 1, bgBlack, styleDim, fgWhite, &"{i + 1}: {option}", resetStyle)
      return selected - 1
    elif newSelected != -1:
      selected = newSelected