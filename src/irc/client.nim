import tables, net, std/re, strutils, ../env/env
{.experimental: "strictDefs".}


type 
  Client* = ref object 
    connections*: seq[client.Channel]
    credentials*: Table[string, string] 
    socket*: Socket
  Events* = enum
    MessageEvent, CommandEvent
  User* = object 
    id*: Natural
    login*, name*: cstring
    tags*: seq[Tag]
  Channel* = ref object 
    id*: Natural
    login*, name*: cstring
  Message* = object 
    id*: Natural
    content*: cstring
    user*: User
    channel*: client.Channel
  Command* = object 
    id*: Natural
    user*: User 
    command*: cstring 
    args*: seq[cstring]
  Tag* = tuple[name, value: string]
  IRCMessage* = enum 
    PRIVMSG, NOTICE, JOIN, PART, RECONNECT, USERNOTICE, ROOMSTATE, USERSTATE, PING
  IRCCommand* = object 
    message*: IRCMessage 
    tags*: seq[Tag]
    prefix*: Prefix
    channel*, msg*: string

  Prefix* = tuple[nick:string, user:string, host:string] 

const  delimiters = [':', '!', '@']

template loop*(code: untyped) = 
  while true:
    code
proc newClient*(): Client = 
  let temp = Client()
  temp.socket = newSocket()
  return temp

proc close*(client: Client) = 
  client.socket.close()

proc joinChannel*(client: Client, name: string): bool = 
  client.socket.send("JOIN #" & name & "\c\L")

proc sendMessage*(client: Client, channel, message: string) = 
  client.socket.send("PRIVMSG #" & channel & " :" & message & "\c\L")

proc leaveChannel*(client: Client, channel: string) = 
  client.socket.send("PART #" & channel & "\c\L")

func getTag*(tags: seq[Tag], name = "", value = ""): Tag = 
  if not name.isEmptyOrWhitespace:
    for i in tags:
      if i.name == name:
        return i
  elif not value.isEmptyOrWhitespace:
    for i in tags:
      if i.value == value:
        return i
  else: 
    return (name:"", value:"")

func hasTags*(input: string): bool {.inline.} = 
  result = input.startsWith('@')
func parseTags*(input: string): seq[Tag] = 
  if input.hasTags:
    let temp = input.split(';')
    var idx = 0
    result = newSeq[Tag]()
    while idx < temp.len - 1:
      let cur = temp[idx].split("=")
      result.add((cur[0], cur[1]))
      inc idx 
func parsePrefix*(input: string): Prefix = 
  if input.startsWith(':'):
    let size = input.len
    var 
      index = 0
      idx = 0
      indx = 0 
      parsingArray: array[3, string]
    while indx < 2: 
      if (delimiters.contains input[index]): 
        if index != idx:
          parsingArray[indx] = input[idx..index - 1]
          idx = index
          inc indx

          
      inc index

    result = (nick: parsingArray[0], user: parsingArray[1], host:input[idx..size-1])
  else: 
    result = (nick:"",user:"",host:"")

func parseIRCMessage(input: string): IRCMessage {.inline.} = 
  if input[0].isUpperascii:
    case input:
      of "PRIVMSG": return PRIVMSG
      of "NOTICE": return NOTICE
      of "JOIN": return JOIN
      of "PART": return PART
      of "RECONNECT": return RECONNECT
      of "USERNOTICE": return USERNOTICE
      of "ROOMSTATE": return ROOMSTATE
      of "USERSTATE": return USERSTATE
      of "PING": return PING 


func parseIRCCommand*(input: string): IRCCommand = 
  if not input.isEmptyOrWhitespace:
    let
      temp = input.split(' ', 1)
    if input.hasTags():
      let
        tmp = temp[1].split(' ')
        prefix = tmp[0].parsePrefix()
        tags = temp[0].parseTags()
        ircMessage = tmp[2].parseIRCMessage()
      return IRCCommand(message:ircMessage, tags:tags, prefix:prefix)





  
proc init*(client: Client) {.gcsafe.} = 
  client.credentials = load("src/env/.env")
  client.socket.connect("irc.chat.twitch.tv", Port(6667))
  client.socket.send("PASS oauth:" & client.credentials["TOKEN"] & "\c\L")
  client.socket.send("NICK digital_red_panda\c\L")
  client.socket.send("CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands\c\L")


