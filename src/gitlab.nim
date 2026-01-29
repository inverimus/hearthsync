import std/json
import std/sequtils
import std/strformat
import std/strutils
import std/sugar

import types
import addonHelp
import select

when not defined(release):
  import logger
  debugLog("gitlab.nim")

proc setDownloadUrlGitlab*(addon: Addon, json: JsonNode) {.gcsafe.} =
  let sources = json[0]["assets"]["sources"]
  # If gameVersion is empty, choose the shortest zip file
  if addon.gameVersion.isEmptyOrWhitespace:
    let urls = collect(
      for source in sources:
        if source["format"].getStr() == "zip":
          source["url"].getStr()
    )
    var shortest = urls[0]
    for url in urls[1..^1]:
      if url.len < shortest.len:
        shortest = url
    addon.downloadUrl = shortest
    return
  # if gameVersion is not empty, choose the zip file that contains it
  for source in sources:
    if source["content_type"].getStr() == "zip":
      let url = source["url"].getStr()
      if url.contains(addon.gameVersion):
        addon.downloadUrl = url
        return
  # if no zip file contains the gameVersion and it is not empty, we fail and ask the user to reinstall
  if not addon.gameVersion.isEmptyOrWhitespace:
    addon.setAddonState(Failed, &"No zip file matching: {addon.gameVersion}. Try reinstalling as file names might have changed.")

proc chooseDownloadUrlGitlab*(addon: Addon, json: JsonNode) {.gcsafe.} =
  if addon.state == Failed: return
  var options: seq[string]
  for source in json[0]["assets"]["sources"]:
    if source["format"].getStr() == "zip":
      options.add(source["url"].getStr())
  case options.len
  of 0:
    addon.setAddonState(Failed, "No zip file found")
    return
  of 1:
    addon.downloadUrl = options[0]
    return
  else:
    let i = addon.userSelect(options.mapIt(it.rsplit("/")[^1]))
    addon.gameVersion = extractVersionFromDifferences(options, i)
    addon.downloadUrl = options[i]