import tables, net, std/re, strutils, ../env/env, parseutils, options, strformat
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
  client.socket.trySend("JOIN #" & name & "\c\L")

proc sendMessage*(client: Client, channel, message: string) = 
  client.socket.send("PRIVMSG #" & channel & " :" & message & "\c\L")

proc leaveChannel*(client: Client, channel: string) = 
  client.socket.send("PART #" & channel & "\c\L")

func getTag*(tags: seq[Tag], name = "", value = ""): Tag = 
  if not name.isEmptyOrWhitespace:
    for i in tags:
      if i.name == name:
        return i
      return (name:"", value:"")
  elif not value.isEmptyOrWhitespace:
    for i in tags:
      if i.value == value:
        return i
    return (name:"", value:"")
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

func parseColor*(input: string): tuple[R,G,B: int] =  
  if input.startsWith('#'):
    let temp = input[1..<input.len]
    var
      RGB: array[3, int]
      indx = 0
    for i in 0..2:
      RGB[i] = temp[indx..indx + 1].parseHexInt
      indx += 2

    return (R:RGB[0], G: RGB[1], B:RGB[2])

func parseIRCCommand*(input: string): IRCCommand = 
  if not input.isEmptyOrWhitespace:
    let
      temp = input.split(' ', 1)
    if input.hasTags():
      let
        tmp = temp[1].split(' ', 3)
        prefix = tmp[0].parsePrefix()
        tags = temp[0].parseTags()
        ircMessage = tmp[2]
      case ircMessage:
        of "PRIVMSG":
          let size = tmp[3].len
          return IRCCommand(message:PRIVMSG, prefix: prefix, channel: tmp[2], msg:tmp[3][1..<size])
        of "NOTICE": discard 
        of "JOIN":  
          return IRCCommand(message:JOIN, prefix: prefix, channel: tmp[2])
        of "PART": 
          return IRCCommand(message:PART, prefix:prefix, channel: tmp[2])
        of "RECONNECT": discard
        of "USERNOTICE": discard
        of "ROOMSTATE": discard
        of "USERSTATE": discard
        of "PING": return IRCCommand(message:PING, prefix:(nick:"", user:"", host:temp[1]))
      return IRCCommand(message:ircMessage.parseIRCMessage, tags:tags, prefix:prefix)





  
proc init*(client: Client) {.gcsafe.} = 
  let temp = load("src/env/.env")
  if temp.isNone:
    raise newException(NilAccessDefect, "unable to load credentials")
  client.credentials = temp.get()
  client.socket.connect("irc.chat.twitch.tv", Port(6667))
  client.socket.send("PASS oauth:" & client.credentials["TOKEN"] & "\c\L")
  client.socket.send("NICK digital_red_panda\c\L")
  client.socket.send("CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands\c\L")


