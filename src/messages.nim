import std/colors
import std/options
import std/strformat
import std/strutils
import std/times
import std/terminal

import addonHelp
import config
import types
import term

when not defined(release):
  import logger
  debugLog("messages.nim")

const LIGHT_GREY: Color = Color(0x34_34_34)

proc stateMessage*(addon: Addon, nameSpace, versionSpace: int) = 
  case addon.state
  of Failed, DoneFailed: return
  else: discard

  let
    t = configData.term
    even = addon.line mod 2 == 0
    branch = if addon.branch.isSome: addon.branch.get else: ""
    
    kind = case addon.kind
    of GithubRepo: "Github"
    else: $addon.kind

    stateColor = case addon.state
    of Checking, Parsing, Downloading, Installing, Restoring: fgCyan
    of FinishedUpdated, FinishedInstalled, FinishedUpToDate, Pinned, FinishedPinned, Removed, Unpinned, Renamed, Restored: fgGreen
    of Failed, NoBackup: fgRed
    else: fgWhite

    versionColor = case addon.state
    of Checking, Parsing, Downloading, Installing, Restoring, FinishedUpToDate, Pinned, FinishedPinned, Unpinned, Renamed, Failed, NoBackup: fgYellow
    of FinishedUpdated, FinishedInstalled, Removed, Restored, Listed: fgGreen
    else: fgWhite
    
  t.write(1, addon.line, true)
  if even:
    t.write((fgWhite, bgDefault), styleBright)
  else:
    t.write((fgWhite, LIGHT_GREY), if not t.trueColor: styleReverse else: styleBright)
  t.write(fgBlue, &"{addon.id:<3}")

  case addon.state
  of Listed:
    let pin = if addon.pinned: "!" else: " "
    let time = addon.time.format("MM-dd-yy hh:mm")
    t.write(
      fgWhite, &"{addon.getName().alignLeft(nameSpace)}",
      fgRed, pin,
      versionColor, &"{addon.getVersion().alignLeft(versionSpace)}",
      fgCyan, &"{kind:<6}",
      fgWhite, if addon.branch.isSome: "@" else: "",
      fgBlue, if addon.branch.isSome: &"{branch:<11}" else: &"{branch:<12}",
      fgWhite, &"{time:<20}"
    )
    if addon.action == ListAll:
      t.write(fgBlue, &"{addon.project:<40}")
  else:
    t.write(
      stateColor, &"{$addon.state:<12}",
      fgWhite, &"{addon.getName().alignLeft(nameSpace)}", 
      versionColor, &"{addon.getVersion().alignLeft(versionSpace)}", 
      fgCyan, &"{kind:<6}", 
      fgWhite, if addon.branch.isSome: "@" else: "", 
      fgBlue, if addon.branch.isSome: &"{branch:<11}" else: &"{branch:<12}"
    )
  
  t.write(resetStyle)