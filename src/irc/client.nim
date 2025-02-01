import tables, net, std/re

type 
  Client* = ref object 
    connections*: seq[Streamer]
    credentials*: TableRef[string, string] 
    socket*: Socket
    events*: seq[Events]
  Events* = enum
    MessageEvent, CommandEvent
  User* = object 
    id*: Natural
    login*, name*: cstring
  Streamer* = ref object 
    id*: Natural
    login*, name*: cstring
  Message* = object 
    id*: Natural
    content*: cstring
    user*: User
    streamer*: Streamer 
  Command* = object 
    id*: Natural
    user*: User 
    command*: cstring 
    args*: seq[cstring]

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
  client.socket.send("PRIVMSG #" & channel & ":" & message & "\c\L")
  
proc init*(client: Client) {.gcsafe.}= 
  client.socket.connect("irc.chat.twitch.tv", Port(6667))
  client.socket.send("PASS oauth:vtp3wx7w4dp9j2znv73n07l6kfh4tv\c\L")
  client.socket.send("NICK digital_red_panda\c\L")


