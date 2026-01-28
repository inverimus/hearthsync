import std/enumerate
import std/httpclient
import std/json
import std/jsonutils
import std/strformat
import std/strutils
import std/terminal
import std/times
import std/xmltree

import pkg/htmlparser

import types
import term

when not defined(release):
  import logger
  debugLog("zremax.nim")

proc extractJsonZremax*(addon: Addon, response: Response): JsonNode {.gcsafe.} =
  var json = newJObject()
  let xml = parseHtml(response.body)
  let divs = xml.findAll("div")
  for node in divs:
    let class = node.attr("class")
    if class == "view-addon_info_header_title_name":
      let name = node.child("h1").innerText()
      json["name"] = %name
      break
  for node in divs:
    let class = node.attr("class")
    if class == "view-addon_info_stats":
      for n in node.items():
        if n.child("div").child("div").child("h2").innerText() == "Updated":
          for item in n.child("div").findAll("div"):
            if item.attr("class") == "view-addon_info_stats_item_value":
              let rawDate = item.child("span").innerText()
              let date = rawDate.replace("th", "").replace("st", "").replace("nd", "").replace("rd", "").parse("MMMM d, yyyy")
              json["version"] = %(date.format("M-d-yyyy"))
              break
  var expansions: seq[string]
  for node in xml.findAll("span"):
    let class = node.attr("class")
    if class == "view-addon_info_header_title_expansions_expansion":
      expansions.add(node.innerText())
  json["expansions"] = %expansions
  return json

proc userSelectGameVersion(addon: Addon, options: seq[string]): string {.gcsafe.} =
  let t = addon.config.term
  var selected = 1
  for _ in 0 ..< options.len:
    t.addLine()
  while true:
    for (i, option) in enumerate(options):
      if selected == i + 1:
        t.write(16, addon.line + i + 1, bgWhite, fgBlack, &"{i + 1}: {option}", resetStyle)
      else:
        t.write(16, addon.line + i + 1, bgBlack, fgWhite, &"{i + 1}: {option}", resetStyle)
    let newSelected = handleSelection(options.len, selected)
    if newSelected == selected:
      t.clear(addon.line .. addon.line + options.len)
      return options[selected - 1]
    elif newSelected != -1:
      selected = newSelected

proc chooseDownloadUrlZremax*(addon: Addon, json: JsonNode) {.gcsafe.} =
  var expansions: seq[string]
  expansions.fromJson(json["expansions"])
  addon.gameVersion = userSelectGameVersion(addon, expansions).toLowerAscii()