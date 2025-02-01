import strutils, tables
proc load*(fileName: string): TableRef = 
  var table = initTable[string, string]()
  for i in fileName.readLines(3):
    let temp = i.split("=")
    table[temp[0], temp[1]] 
  return table

