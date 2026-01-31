import std/httpclient
import std/json
import std/re
import std/sequtils
import std/strutils
import std/strformat

import ../types
import ../addonHelp
import ../select

when not defined(release):
  import ../logger
  debugLog("wago.nim")

proc versionWago*(addon: Addon, json: JsonNode): string {.gcsafe.} =
  for data in json["props"]["releases"]["data"]:
    if data["supported_" & addon.gameVersion & "_patches"].len > 0:
      result = data["label"].getStr()
      break
  result = result.replace(json["props"]["addon"]["display_name"].getStr(), "")
  result = result.strip(chars = {' ', '_', '-', '.'})

proc setDownloadUrlWago*(addon: Addon, json: JsonNode) {.gcsafe.} =
  for data in json["props"]["releases"]["data"]:
    if data["supported_" & addon.gameVersion & "_patches"].len > 0:
      addon.downloadUrl = data["download_link"].getStr()
      return
  addon.setAddonState(Failed, &"JSON Error: No release matches current verion: {addon.gameVersion}.")

proc getVersionName(version: string): string =
  case version
  of "retail":  result = "Retail"
  of "cata":    result = "Cataclysm Classic"
  of "wotlk":   result = "WotLK Classic"
  of "bc":      result = "TBC Classic"
  of "classic": result = "Classic (Vanilla 1.15)"
  of "mop":     result = "MoP Classic"
  else:         result = "Unknown"

proc chooseDownloadUrlWago*(addon: Addon, json: JsonNode) {.gcsafe.} =
  var gameVersions: seq[string]
  for data in json["props"]["releases"]["data"]:
    let patches = ["retail", "mop", "classic", "bc", "wotlk", "cata"]
    for patch in patches:
      if data["supported_" & patch & "_patches"].len > 0:
        gameVersions.addUnique(patch)
  if gameVersions.len == 1:
    addon.gameVersion = gameVersions[0]
  else:
    addon.gameVersion = gameVersions[addon.userSelect(gameVersions.mapIt(getVersionName(it)))]

proc extractJsonWago*(addon: Addon, response: Response): JsonNode {.gcsafe.} =
  let pattern = re("""data-page="({.+?})"""")
  var matches: array[1, string]
  if find(cstring(response.body), pattern, matches, 0, len(response.body)) != -1:
    let clean = matches[0].replace("&quot;", "\"").replace("\\/", "/").replace("&amp;", "&")
    try:
      result = parseJson(clean)
    except:
      setAddonState(addon, Failed, "Error parsing JSON.")
  else:
    setAddonState(addon, Failed, "Embedded JSON not found.")
    return