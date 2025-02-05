import strutils, tables, std/os, options
proc load*(fileName: string): Option[Table[string,string]] =
  if fileName.fileExists:
    result = some(initTable[string, string]())
    for i in fileName.readLines(3):
      let temp = i.split("=")
      result.get[temp[0]] =  temp[1]
  else:
    result = none[Table[string,string]]()
      
