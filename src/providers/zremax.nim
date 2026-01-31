import std/httpclient
import std/json
import std/jsonutils
import std/strutils
import std/times
import std/xmltree

import pkg/htmlparser

import ../types
import ../select
import ../addonHelp

when not defined(release):
  import ../logger
  debugLog("zremax.nim")

proc extractJsonZremax*(addon: Addon, response: Response): JsonNode {.gcsafe.} =
  var json = newJObject()
  var xml: XmlNode
  try:
    xml = parseHtml(response.body)
  except Exception as e:
    addon.setAddonState(Failed, "Error parsing HTML", e)
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

  if not json.hasKey("name") or not json.hasKey("version") or expansions.len == 0:
    addon.setAddonState(Failed, "Unable to extract information from HTML")
  
  return json



proc chooseDownloadUrlZremax*(addon: Addon, json: JsonNode) {.gcsafe.} =
  var expansions: seq[string]
  expansions.fromJson(json["expansions"])
  addon.gameVersion = expansions[addon.userSelect(expansions)].toLowerAscii()