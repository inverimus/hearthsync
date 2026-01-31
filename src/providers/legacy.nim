import std/httpclient
import std/json
import std/re
import std/strutils
import std/xmltree

import pkg/htmlparser

import ../addonHelp
import ../types

proc extractJsonLegacy*(addon: Addon, response: Response): JsonNode {.gcsafe.} =
  result = newJObject()
  var html: XmlNode
  try:
    html = parseHtml(response.body)
  except Exception as e:
    addon.setAddonState(Failed, "Error parsing HTML", e)
  for a in html.findAll("a"):
    if a.attr("href") == "Download":
      let onclick = a.attr("onclick")
      let p = re("""updateC\('(.+?)','.*""")
      var m: array[1, string]
      if find(cstring(onclick), p, m, 0, len(onclick)) != -1:
        let download = m[0].replace(" ", "%20")
        result["url"] = %download
        break
  
  for h1 in html.findAll("h1"):
    if h1.attr("class") == "entry-title":
      result["name"] = %h1.innerText()
      break
  
  if not result.hasKey("name") or not result.hasKey("url"):
    addon.setAddonState(Failed, "Unable to extract information from HTML")