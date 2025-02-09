import strutils, tables, std/os, options
proc load*(fileName: string): Option[Table[string,string]] =
  if fileName.fileExists:
    result = some(initTable[string, string]())
    for i in fileName.readLines(4):
      let temp = i.split("=")
      result.get[temp[0]] =  temp[1]
  else:
    result = none[Table[string,string]]()

proc write*(fileName: string, info: Table[string,string]) =
  if not fileName.fileExists:
    var file: File
    if open(file, fileName):
      for key, value in pairs(info): 
        file.writeLine(key & '=' & value)
