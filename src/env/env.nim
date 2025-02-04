import strutils, tables
proc load*(fileName: string): Table[string,string] = 
  result = initTable[string, string]()
  for i in fileName.readLines(3):
    let temp = i.split("=")
    result[temp[0]] =  temp[1]
    
