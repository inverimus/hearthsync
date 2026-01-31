import std/httpclient
import std/json
import std/re
import std/xmltree

import pkg/htmlparser

proc extractJsonLegacy*(response: Response): JsonNode {.gcsafe.} =
  result = newJObject()
  for a in parseHtml(response.body).findAll("a"):
    if a.attr("href") == "Download":
      let onclick = a.attr("onclick")
      let p = re("""updateC\('(.+?)','.*""")
      var m: array[1, string]
      if find(cstring(onclick), p, m, 0, len(onclick)) != -1:
        result["downloadUrl"] = %m[0]
        break