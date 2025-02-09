import tables, net, std/re, strutils, ../env/env, parseutils, options, strformat, os, httpclient, json
{.experimental: "strictDefs".}


type 
  User* = object 
    id*: Natural
    login*, displayName*: string
    tags*: seq[Tag]
  Client* = ref object 
    connections*: seq[client.Channel]
    credentials*: Table[string, string] 
    user*: User
    httpClient: HttpClient 
    socket*: Socket
  Events* = enum
    MessageEvent, CommandEvent
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
    UNKOWN, PRIVMSG, NOTICE, JOIN, PART, RECONNECT, USERNOTICE, ROOMSTATE, USERSTATE, PING
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
  temp.httpClient = newHttpClient()
  return temp

proc validate*(client: Client, token: string): tuple[valid:bool, content:string] = 
  client.httpClient.headers.add("Authorization", "Bearer " & token)
  let response = client.httpClient.request("https://id.twitch.tv/oauth2/validate", httpMethod=HttpGet, headers=client.httpClient.headers)
  if response.status == "401":
    return (false, "")
  else:
    return (true, response.body)
proc getUser*(client: Client, login="", id=""): User =
  if login.isEmptyOrWhitespace:
    if not client.httpClient.headers.hasKey("Client-Id"):
      client.httpClient.headers.add("Client-Id", client.credentials["CLIENT_ID"])
    let 
      response = client.httpClient.request("https://api.twitch.tv/helix/users?id=" & id)
      body = response.body.parseJson["data"][0]

    return User(login:body["login"].getStr, displayName:body["display_name"].getStr, id:body["id"].getStr.parseInt.Natural) 
  elif id.isEmptyOrWhitespace:
    if not client.httpClient.headers.hasKey("Client-Id"):
      client.httpClient.headers.add("Client-Id", client.credentials["CLIENT_ID"])
    let 
      response = client.httpClient.request("https://api.twitch.tv/helix/users?login=" & login)
      body = response.body.parseJson["data"][0]

    return User(login:body["login"].getStr, displayName:body["display_name"].getStr, id:body["id"].getStr.parseInt.Natural) 
  result = User()

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
  elif not value.isEmptyOrWhitespace:
    for i in tags:
      if i.value == value:
        return i
  else: 
    return (name:"", value:"")

func hasTags*(input: string): bool {.inline.} = 
  result = input[0] == '@'
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
  if input.startsWith(":t"):
    result = (nick:"", user:"", host:input)
  elif input.startsWith(':'):
    let
      size = input.len
    var 
      index = 0
      idx = 0
      indx = 0 
      parsingArray = newSeqOfCap[string](3)
    while index < size: 
      if (delimiters.contains input[index]): 
        if index != idx:
          parsingArray.add(input[idx..index - 1])
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
      else: discard

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
  else: 
    return (R:0,G:0,B:0)

proc parseIRCCommand*(input: string): IRCCommand = 
  if not input.isEmptyOrWhitespace:
    if input.hasTags():
      let
        temp = input.split(' ', 4)
        ircMessage = temp[2]
        tags = temp[0].parseTags 
        prefix = temp[1].parsePrefix
        channel = temp[3]
      case ircMessage:
        of "PRIVMSG":
          result = IRCCommand(message:PRIVMSG, tags:tags, prefix:prefix, channel:channel[1..<channel.len], msg:temp[4][1..<temp[4].len])
        of "USERSTATE":
          result = IRCCommand(message:USERSTATE, tags:tags, prefix:prefix, channel:channel[1..<channel.len])
        else: result = IRCCommand()

#        prefix = tmp[0].parsePrefix()
#        tags = temp[0].parseTags()
#        ircMessage = tmp[2]
#      case ircMessage:
#        of "PRIVMSG":
#          let size = tmp[3].len
#          return IRCCommand(tags:tags, message:PRIVMSG, prefix: prefix, channel: tmp[2], msg:tmp[3][1..<size])
#        of "NOTICE": discard 
#      #  of "JOIN":  
#      #    return IRCCommand(message:JOIN, prefix: prefix, channel: tmp[2])
#      #  of "PART": 
#      #    return IRCCommand(message:PART, prefix:prefix, channel: tmp[2])
#        of "RECONNECT": discard
#      #  of "USERNOTICE": discard
#      #  of "ROOMSTATE": discard
#      #  of "USERSTATE": discard
#        of "PING": return IRCCommand(message:PING, prefix:(nick:"", user:"", host:temp[1]))
#      return IRCCommand(message:ircMessage.parseIRCMessage, tags:tags, prefix:prefix)
#    else:
#      if temp[0].startsWith(':'):
#        discard
#      elif temp[0].startsWith('P'):
#        return IRCCommand(message:PING, prefix:(nick:"", user:"", host: temp[1]))
      #case ircMessage

    else: discard

  else: discard

  
proc init*(client: var Client) = 
  let temp = load("src/env/.env")
  if temp.isNone:
    raise newException(NilAccessDefect, "unable to load credentials")
  client.credentials = temp.get()
  client.socket.connect("irc.chat.twitch.tv", Port(6667))
  client.socket.send("PASS oauth:" & client.credentials["TOKEN"] & "\c\L")
  client.socket.send("NICK digital_red_panda\c\L")
  client.socket.send("CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands\c\L")
  client.user = User(login:client.credentials["LOGIN"], id:client.credentials["ID"].parseInt)
  discard client.joinChannel(client.user.login)
  for i in 0..10:
    discard client.socket.recvLine
  let tst = client.socket.recvLine.parseIRCCommand
  client.user.tags = tst.tags
  client.user.displayName = client.user.tags.getTag("display-name").value


