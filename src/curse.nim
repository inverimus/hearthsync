import std/enumerate
import std/sets
import std/[json, jsonutils]
import std/sequtils
import std/[strformat, strutils]
import std/terminal

import types
import term
import addonHelp

proc nameCurse*(addon: Addon, json: JsonNode): string {.gcsafe.} =
  result = json["fileName"].getStr().split('-')[0]
  if addon.name.endsWith(".zip"):
    result = json["fileName"].getStr().split('_')[0]
  if addon.name.endsWith(".zip"):
    result = json["fileName"].getStr().split('.')[0]

proc versionCurse*(addon: Addon, json: JsonNode): string {.gcsafe.} =
  try:
    result = json["displayName"].getStr()
    if addon.version.endsWith(".zip"):
      result = json["dateModified"].getStr()  
  except KeyError:
    result = json["dateModified"].getStr()

proc extractJsonCurse*(addon: Addon, json: JsonNode): JsonNode {.gcsafe.} =
  var gameVersions: seq[string]
  for data in json["data"]:
    gameVersions.fromJson(data["gameVersions"])
    for version in gameVersions:
      if addon.gameVersion == "Retail":
        if version.split(".")[0] == RETAIL_VERSION:
          return data
      else:
        if version.rsplit(".", maxSplit = 1)[0] == addon.gameVersion:
          return data
  addon.setAddonState(Failed, &"JSON Error: No game version matches current verion of {addon.gameVersion}.", 
    &"JSON Error: {addon.getName()}: no game version matches current mode of {addon.gameVersion}.")
  return

proc userSelectGameVersion(addon: Addon, options: seq[string]): string {.gcsafe.} =
  let t = addon.config.term
  var selected = 1
  for _ in 0 ..< options.len:
    t.addLine()
  while true:
    for (i, option) in enumerate(options):
      var version: string
      if option == "Retail":
        version = &"Retail ({RETAIL_VERSION})"
      else:
        let optionSplit = option.split(".")
        let majorVersion = parseInt(optionSplit[0])
        let minorVersion = parseInt(optionSplit[1])
        case majorVersion
        of 12:
          case minorVersion
          of 0..2: version = "Midnight"
          else: version = "Midnight Classic"
        of 11:
          case minorVersion
          of 0..2: version = "The War Within"
          else: version = "TWW Classic"
        of 10:
          case minorVersion
          of 0..2: version = "Dragonflight"
          else: version = "Dragonflight Classic"
        of 9:
          case minorVersion
          of 0..2: version = "Shadowlands"
          else: version = "Shadowlands Classic"
        of 8:
          case minorVersion
          of 0..3: version = "Battle for Azeroth"
          else: version = "BfA Classic"
        of 7:
          case minorVersion
          of 0..3: version = "Legion"
          else: version = "Legion Classic"
        of 6:
          case minorVersion
          of 0..2: version = "Warlords of Draenor"
          else: version = "WoD Classic"
        of 5:
          case minorVersion
          of 0..4: version = "Mists of Pandaria"
          else: version = "MoP Classic"
        of 4:
          case minorVersion
          of 0..3: version = "Cataclysm"
          else: version = "Cataclysm Classic"
        of 3:
          case minorVersion
          of 0..3: version = "Wrath of the Lich King"
          else: version = "WotLK Classic"
        of 2:
          case minorVersion
          of 0..4: version = "The Burning Crusade"
          else: version = "TBC Classic"
        of 1:
          case minorVersion
          of 0..12: version = "Vanilla"
          else: version = "Classic"
        else: discard
      if selected == i + 1:
        t.write(16, addon.line + i + 1, false, bgWhite, fgBlack, &"{i + 1}: {version}", resetStyle)
      else:
        t.write(16, addon.line + i + 1, false, bgBlack, fgWhite, &"{i + 1}: {version}", resetStyle)
    let newSelected = handleSelection(options.len, selected)
    if newSelected == selected:
      t.clear(addon.line .. addon.line + options.len)
      return options[selected - 1]
    elif newSelected != -1:
      selected = newSelected

proc chooseJsonCurse*(addon: Addon, json: JsonNode): JsonNode {.gcsafe.} =
  if json["data"].len == 0:
    addon.setAddonState(Failed, "Addon not found.", "Addon not found.")
    return
  var gameVersionsSet: OrderedSet[string]
  for data in json["data"]:
    var tmp: seq[string]
    tmp.fromJson(data["gameVersions"])
    for item in tmp:
      gameVersionsSet.incl(item.rsplit(".", maxSplit = 1)[0])
  var gameVersions = gameVersionsSet.toSeq()
  gameVersions.insert("Retail", 0)
  var selectedVersion = addon.userSelectGameVersion(gameVersions)
  addon.gameVersion = selectedVersion
  for data in json["data"]:
    var tmp: seq[string]
    tmp.fromJson(data["gameVersions"])
    if selectedVersion == "Retail":
      if tmp.anyIt(it.split(".")[0] == RETAIL_VERSION):
        return data
    else:
      if tmp.anyIt(it.rsplit(".", maxSplit = 1)[0] == selectedVersion):
        return data