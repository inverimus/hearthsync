import std/httpclient
import std/json
import std/options
import std/strformat
import std/strutils
import std/sugar

import ../types
import ../logger
import ../addonHelp
import ../select

proc fallbackToGithubRepo*(addon: Addon, client: HttpClient, response: Response) {.gcsafe.} =
  log(&"{addon.getName()}: Got {response.status}: {addon.getLatestUrl()} - This usually means no releases are available so trying main/master branch", Warning)
  let resp = client.get(&"https://api.github.com/repos/{addon.project}/branches")
  let branches = parseJson(resp.body)
  try:
    if branches["message"].getStr() == "Not Found":
      addon.setAddonState(Failed, "Addon not found")
      return
  except KeyError:
    discard
  let names = collect(for item in branches: item["name"].getStr())
  if names.contains("master"):
    addon.branch = some("master")
  elif names.contains("main"):
    addon.branch = some("main")
  else:
    log(&"{addon.getName()}: No branch named master or main avaialable", Warning)
    addon.setAddonState(Failed, &"Bad response retrieving latest addon info - {response.status}: {addon.getLatestUrl()}")
  addon.kind = GithubRepo

proc setDownloadUrlGithub*(addon: Addon, json: JsonNode) {.gcsafe.} =
  let assets = json["assets"]
  # if gameVersion is zipball, use the zipball_url
  if addon.gameVersion == "zipball":
    addon.downloadUrl = json["zipball_url"].getStr()
    return
  # If gameVersion is empty, choose the shortest zip file
  if addon.gameVersion.isEmptyOrWhitespace:
    let names = collect(
      for i, asset in assets:
        if asset["content_type"].getStr() == "application/zip":
          (i, asset["name"].getStr())
    )
    var shortest = names[0]
    for name in names[1..^1]:
      if name[1].len < shortest[1].len:
        shortest = name
    addon.downloadUrl = assets[shortest[0]]["browser_download_url"].getStr()
    return
  # if gameVersion is not empty, choose the zip file that contains it
  for asset in assets:
    if asset["content_type"].getStr() != "application/zip":
      continue
    let name = asset["name"].getStr()
    if name.contains(addon.gameVersion):
      addon.downloadUrl = asset["browser_download_url"].getStr()
      return
  # if no zip file contains the gameVersion and it is not empty, we fail and ask the user to reinstall
  if not addon.gameVersion.isEmptyOrWhitespace:
    addon.setAddonState(Failed, &"No zip file matching: {addon.gameVersion}. Try reinstalling as file names might have changed.")
        
proc chooseDownloadUrlGithub*(addon: Addon, json: JsonNode) {.gcsafe.} =
  if addon.state == Failed: return
  let assets = json["assets"]
  var options: seq[string]
  for asset in assets:
    if asset["content_type"].getStr() == "application/zip":
      options.add(asset["name"].getStr())
  case options.len
  of 0:
    addon.gameVersion = "zipball"
    addon.downloadUrl = json["zipball_url"].getStr()
    return
  of 1:
    addon.downloadUrl = assets[0]["browser_download_url"].getStr()
    return
  else:
    let i = addon.userSelect(options)
    addon.gameVersion = extractVersionFromDifferences(options, i)
    addon.downloadUrl = assets[i]["browser_download_url"].getStr()