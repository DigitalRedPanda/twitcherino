# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import illwill, os, sequtils, sugar, irc/client, std/strformat, re, net, strutils, asyncdispatch, tables, terminal, json, rdstdin, env/env


  
type Message = object 
  channel,user, message: string 

var
  channel: system.Channel[Message]

proc handleMessages(client: Client) {.thread, gcsafe} =

  loop:
    let
      tmp = client.socket.recvLine() 
      args = tmp.split(' ', 3)
    #channel.send(tmp)
    if args[0] == "PING":
      client.socket.send("PONG :tmi.twitch.tv\c\L")
    else: 
      var
        command = tmp.parseIRCCommand
      case command.message:
        of PRIVMSG:
          let
            color = command.tags.getTag(name="color").value.parseColor
            displayName = command.tags.getTag("display-name")
            #separator = "\e[{$(textColor.len + 4)}"
            message = ":\e[0m " & command.msg.replace(" ", " ")
            msg = Message(channel:command.channel, user: &"\e[38;2;{$color.R};{$color.G};{$color.B}m{displayName.value}", message: message)
          #channel.send(&"{textColor}{displayName.value}\e[0m,: {message}")
          channel.send(msg)
        else: discard
     


proc drawTab(buffer: var TerminalBuffer, x,y: Natural, content: string, padding: Natural, double = false) = 
  buffer.drawRect(x, y, x + content.len + 1 + padding, y + padding, double)
  buffer.write(x + padding, y + padding div 2, content)

func drawInputBox(buffer: var TerminalBuffer, x,y,width: Natural, placeholder,text: string) = 
  let left = x - (width div 2)
  buffer.drawRect(left, y - 1, x + (width div 2), y + 1)
  if text.isEmptyOrWhitespace:
    buffer.write(left + 1, y, placeholder)
  else:
    buffer.write(left + 1, y, text)

type Mode = enum
  Normal, Insert


proc main = 
  var 
    client = newClient()
    authenticated = true
  const mesg = "  \e[1;36m\e[4mhttps://id.twitch.tv/oauth2/authorize?client_id=yclsy2qxp7jelxtbl09my7wvk8w3b2&redirect_uri=https%3A%2F%2Flocalhost&response_type=token&scope=channel%3Amoderate+channel%3Aread%3Aredemptions+chat%3Aedit+chat%3Aread+whispers%3Aread+channel%3Aedit%3Acommercial+clips%3Aedit+channel%3Amanage%3Abroadcast+user%3Aread%3Ablocked_users+user%3Amanage%3Ablocked_users+moderator%3Amanage%3Aautomod+channel%3Amanage%3Araids+channel%3Amanage%3Apolls+channel%3Aread%3Apolls+channel%3Amanage%3Apredictions+channel%3Aread%3Apredictions+moderator%3Amanage%3Aannouncements+user%3Amanage%3Awhispers+moderator%3Amanage%3Abanned_users+moderator%3Amanage%3Achat_messages+user%3Amanage%3Achat_color+moderator%3Amanage%3Achat_settings+channel%3Amanage%3Amoderators+channel%3Amanage%3Avips+moderator%3Aread%3Achatters+moderator%3Amanage%3Ashield_mode+moderator%3Amanage%3Ashoutouts+user%3Aread%3Amoderated_channels+user%3Aread%3Achat+user%3Awrite%3Achat+user%3Aread%3Aemotes+moderator%3Amanage%3Awarnings+user%3Aread%3Afollows\e[22m\e[24m\e[0m\n\nYou'll be prompted to sign in, then authorization. After that you'll end up in an `\e[1mUnable to connect\e[22m`, if you look carefully at the URL, you'd find `#access_token=\e[1m<TOKEN>\e[22m`double-click on \e[1m<TOKEN>\e[22m, copy it, then paste it in the terminal"
  const mesg1 = "  \e[1;36m\e[4mhttps://id.twitch.tv/oauth2/authorize?client_id=yclsy2qxp7jelxtbl09my7wvk8w3b2&redirect_uri=https%3A%2F%2Flocalhost&response_type=token&scope=channel%3Amoderate+channel%3Aread%3Aredemptions+chat%3Aedit+chat%3Aread+whispers%3Aread+channel%3Aedit%3Acommercial+clips%3Aedit+channel%3Amanage%3Abroadcast+user%3Aread%3Ablocked_users+user%3Amanage%3Ablocked_users+moderator%3Amanage%3Aautomod+channel%3Amanage%3Araids+channel%3Amanage%3Apolls+channel%3Aread%3Apolls+channel%3Amanage%3Apredictions+channel%3Aread%3Apredictions+moderator%3Amanage%3Aannouncements+user%3Amanage%3Awhispers+moderator%3Amanage%3Abanned_users+moderator%3Amanage%3Achat_messages+user%3Amanage%3Achat_color+moderator%3Amanage%3Achat_settings+channel%3Amanage%3Amoderators+channel%3Amanage%3Avips+moderator%3Aread%3Achatters+moderator%3Amanage%3Ashield_mode+moderator%3Amanage%3Ashoutouts+user%3Aread%3Amoderated_channels+user%3Aread%3Achat+user%3Awrite%3Achat+user%3Aread%3Aemotes+moderator%3Amanage%3Awarnings+user%3Aread%3Afollows\e[22m\e[24m\e[0m\n\nYou'll be prompted to sign in, then authorization. After that you'll end up in an `\e[1mUnable to connect\e[22m`, if you look carefully at the URL, you'd find `#access_token=\e[1m<TOKEN>\e[22m`double-click on \e[1m<TOKEN>\e[22m, copy it, then press enter, and paste in the box"

  try:
    
    client.init()
  except NilAccessDefect: 
    let 
      center = terminalWidth() div 2 - (46 div 2)
      width = terminalWidth()
    stdout.write("\e[2J\e[0;0H")
    stdout.write(&"""

{"=".repeat(width)}
{" ".repeat(center)}__        _______ _     ____ ___  __  __ _____
{" ".repeat(center)}\ \      / / ____| |   / ___/ _ \|  \/  | ____|
{" ".repeat(center)} \ \ /\ / /|  _| | |  | |  | | | | |\/| |  _|
{" ".repeat(center)}  \ V  V / | |___| |__| |__| |_| | |  | | |___
{" ".repeat(center)}   \_/\_/  |_____|_____\____\___/|_|  |_|_____|    
{"=".repeat(width)}

if you received this message, then this indicates that probably this is your first time launching this app. To set things up, you first need to generate a token using the link marked by bold:

{mesg1}
""")

    let s =  getch()
    if s == 0x03.chr or s == 0x1B.chr:
      stdout.writeLine("[\e[1;34mINFO\e[0m] cancelling")
      return
    authenticated = false
  illwillInit()
  if not authenticated:
    var
      currentIndex = 0.Natural
      token = ""
    stdout.write("\e[38;5;239m")
    while true:
      let
        width = terminalWidth()
        height = terminalHeight()
      var
        buffer = newTerminalBuffer(width, height)
      
      buffer.drawRect(0, 0, width - 1, height - 1, true)
      buffer.drawInputBox(x=(width div 2).Natural, y=(height div 2).Natural, width=40, placeholder="Enter token", text="*".repeat(token.len))
      stdout.write("\e[37m")
      let key = getKey()
      sleep 1
      case key:
        of Right:
          if currentIndex < token.len - 1:
            inc currentIndex
        of Left:
          if currentIndex > 0:
            dec currentIndex
        of Escape: 
          quit(0)
        of Tab: discard
        of Backspace:
          if token.len > 0:
            token = token[0..token.len - 2]
            dec currentIndex 
        of None:
          discard
        of Enter:
          let response = client.validate(token)
          if response.valid:
            try:
              let body = response.content.parseJson
              var credentials = initTable[string,string]()
              credentials["CLIENT_ID"] = body["client_id"].getStr
              credentials["LOGIN"] = body["login"].getStr
              credentials["ID"] = body["user_id"].getStr
              credentials["TOKEN"] = token
              client.credentials = credentials
              write("src/env/.env", credentials)
              client.init
              buffer.clear
              stdout.write("\e[38;5;239m")
            except KeyError:
              stdout.writeLine("\e[2J\e[0;0H[\e[1;31mERROR\e[0m] Invalid token")
              quit(1)
              
            break
          else:
            currentIndex = 0
            token = ""
        else: 
          token.insert("" & key.char, currentIndex)
          inc currentIndex
      buffer.display

  open(channel)
  hideCursor()
  defer: 
    illwillDeinit()
    showCursor()
    channel.close()
    client.close()
    quit("[\e[32mINFO\e[0m] exiting\e[?47l\e[u\e[1049l", 0)

  setControlCHook(
    proc() {.noconv.} = 
      illwillDeinit()
      showCursor()
      quit("[\e[32mINFO\e[0m] exiting", 0)
    )


  var
    thread: Thread[Client]
    messagesList = newSeq[twicherino.Message]()
    channels = newSeq[string]()
    mode = Normal
    command = ""
    cursor = " "
    currentChannel = client.user.login
    currentChannelIndex = 0
    addingChannel = false
    color = illwill.bgWhite
  createThread(thread, handleMessages, client)

  channels.add(currentChannel)
  while true:
    let
      width = terminalWidth()
      height = terminalHeight()
    var
      buffer = newTerminalBuffer(width, height)
    buffer.drawRect(0, 0, width - 1, height - 1, true)
    var 
      widthSum = 0
      heightSum = 0
    for channel in channels:
      if widthSum >= width:
        widthSum = 0
        heightSum += 3
      let
        x = widthSum + 1
        y = heightSum + 1
      if currentChannel == channel:
        buffer.drawTab(x, y, channel, 2, true)
        widthSum += abs(widthSum - (x + channel.len)) + 3
        continue
      buffer.drawTab(x, y, channel, 2)
      widthSum += abs(widthSum - (x + channel.len)) + 3
      
    let msg = channel.tryRecv()
    if msg.dataAvailable:
      messagesList.add(msg.msg)
    var currChannelMsgs = messagesList.filter(x => x.channel == currentChannel).toSeq
    for i, message in currChannelMsgs:
      buffer.write(1, heightSum + i + 4, message.user &  message.message)
    let key = getkey()
    if mode == Normal:
      case key:
        of A..Z, ShiftA..ShiftZ, Zero..Nine,Underscore:
          if addingChannel:
            command &= key.char
          elif key.char == 'j':
            addingChannel = true
            buffer.drawInputBox(x=(width div 2).Natural, y=(height div 2).Natural, width=15.Natural, placeholder="Enter channel", text=command)
          elif key == I:
            mode = Insert
            cursor = "▏"
            color = bgNone

        of Enter:
          if addingChannel and not command.isEmptyOrWhitespace:
            discard client.joinChannel(command)
            channels.addUnique command
            addingChannel = false 
            command = ""
        of Escape: 
          if addingChannel:
            addingChannel = false
        of Backspace:
          if addingChannel:
            if command.len > 0:
             command = command[0..command.len - 2]
        of Left:
          if currentChannelIndex > 0 and currentChannelIndex < channels.len:
            currentChannelIndex -= 1
            currentChannel = channels[currentChannelIndex]
        of Right: 
          if currentChannelIndex >= 0 and currentChannelIndex < channels.len - 1:
            currentChannelIndex += 1
            currentChannel = channels[currentChannelIndex]

        else: discard

    else: 
      case key:
        of Escape:
          mode = Normal
          color = bgWhite
          command = ""
        of Backspace:
          if command.len > 0:
           command = command[0..command.len - 2]
        of Space:
          command &= ' '
        of Enter:
          if not command.isEmptyOrWhitespace:
            client.sendMessage(currentChannel, command)
            let 
              chatColor = client.user.tags.getTag("color").value.parseColor
              message = ":\e[0m " & command.replace(" ", " ")
            messagesList.add(Message(channel:currentChannel, user: &"\e[38;2;{$chatColor.R};{$chatColor.G};{$chatColor.B}m" & client.user.displayName, message: message))
            mode = Normal 
            cursor = " "
            color = bgWhite
            command = ""
        of None:
          discard
        else: 
          command &= key.char

    if addingChannel:
      buffer.drawInputBox(x=(width div 2).Natural, y=(height div 2).Natural, width=15.Natural, placeholder="Enter channel", text=command)
    else:
      buffer.setForegroundColor(fgWhite)
      buffer.write(2, height - 2, command)
      buffer.setBackgroundColor(color)
      buffer.write(2 + command.len, height - 2, cursor)
    stdout.write("\e[38;5;239m")
    buffer.display()

proc main1 = 
  var 
    channels = @["Zaaatar", "1dzo", "SadMadLadSalman", "SoulSev", "CopyNine"]
    messages = @["dummy", "dumdum", "donk", "dank"]
    client = newClient()
  client.init()
#  illwillInit()
  open(channel)
  hideCursor()
  defer: 
    #illwillDeinit()
    showCursor()
    channel.close()
    client.close()
    quit("[\e[32mINFO\e[0m] exiting\e[?47l\e[u\e[1049l", 0)

#  setControlCHook(
#    proc() {.noconv.} = 
#      illwillDeinit()
#      showCursor()
#      quit("[\e[32mINFO\e[0m] exiting", 0)
#    )
  var
    thread: Thread[Client]
    messagesList = newSeq[string]()
  createThread(thread, handleMessages, client)
  
  while true:
#    let
#      width = terminalWidth()
#      height = terminalHeight()
#    var
#      buffer = newTerminalBuffer(width, height)
#    stdout.write("\e[38;5;239m")
#    buffer.drawRect(0, 0, width - 1, height - 1, true)
#    var 
#      widthSum = 0
#      heightSum = 0
#    for channel in channels:
#      if widthSum >= width:
#        widthSum = 0
#        heightSum += 3
#      let
#        x = widthSum + 1
#        y = heightSum + 1
#      buffer.drawTab(x, y, channel, 2)
#      widthSum += abs(widthSum - (x + channel.len)) + 3
    let msg = channel.recv()
    #messagesList.add(msg)
    echo msg
#    for i, message in messagesList:
#      buffer.write(1, heightSum + i + 4, message)
#    buffer.setForegroundColor(fgWhite)
#    let key = getkey()
#    case key:
#      of Key.Escape:
#        break
#      else: discard
#    buffer.display()
        


main()
# Example demonstrating the various box drawing methods.

#import illwill
#import os
#
#
#proc exitProc() {.noconv.} =
#  illwillDeinit()
#  showCursor()
#  quit(0)
#
#proc main() =
#  illwillInit(fullscreen=true)
#  setControlCHook(exitProc)
#  hideCursor()
#
#  while true:
#    var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
#
#    var key = getKey()
#    case key
#    of Key.Escape, Key.Q: exitProc()
#    else: discard
#
#    tb.write(0, 0, "Press Q, Esc or Ctrl-C to quit")
#
#    # (1) TerminalBuffer.drawRect doesn't connect overlapping lines
#    tb.setForegroundColor(fgGreen)
#    tb.drawRect(2, 3, 14, 5, doubleStyle=true)
#    tb.drawRect(6, 2, 10, 6)
#
#    tb.write(7, 7, fgWhite, "(1)")
#
#    # (2) BoxBuffer.drawRect, however, does by default
#    var bb = newBoxBuffer(tb.width, tb.height)
#    bb.drawRect(20, 3, 32, 5, doubleStyle=true)
#    bb.drawRect(24, 2, 28, 6)
#    tb.setForegroundColor(fgBlue)
#    tb.write(bb)
#
#    tb.write(25, 7, fgWhite, "(2)")
#
#    # (3) BoxBuffer.drawRect with connect=false
#    bb = newBoxBuffer(tb.width, tb.height)
#    bb.drawRect(38, 3, 50, 5, doubleStyle=true, connect=false)
#    bb.drawRect(42, 2, 46, 6, connect=false)
#    tb.setForegroundColor(fgRed)
#    tb.write(bb)
#
#    tb.write(43, 7, fgWhite, "(3)")
#
#    # (4) Smallest possible rectangle to draw
#    tb.setForegroundColor(fgWhite)
#    tb.drawRect(7, 9, 8, 10)
#
#    tb.write(7, 11, fgWhite, "(4)")
#
#    # (5) Rectangle too small, draw nothing
#    tb.setForegroundColor(fgMagenta)
#    tb.drawRect(25, 9, 25, 9)
#
#    tb.write(25, 11, fgWhite, "(5)")
#
#    # (6) TerminalBuffer.drawHorizLine/drawVertLine doesn't connect
#    # overlapping lines
#    tb.setForegroundColor(fgYellow)
#    tb.drawHorizLine(2, 14, 14, doubleStyle=true)
#    tb.drawVertLine(4, 13, 15, doubleStyle=true)
#    tb.drawVertLine(6, 13, 15)
#    tb.drawVertLine(10, 13, 16)
#    tb.drawHorizLine(4, 12, 15, doubleStyle=true)
#
#    tb.write(7, 17, fgWhite, "(6)")
#
#    # (7) TerminalBuffer.drawHorizLine/drawVertLine does connect
#    # overlapping lines by default
#    bb = newBoxBuffer(tb.width, tb.height)
#    bb.drawHorizLine(20, 32, 14, doubleStyle=true)
#    bb.drawVertLine(22, 13, 15, doubleStyle=true)
#    bb.drawVertLine(24, 13, 15)
#    bb.drawVertLine(28, 13, 16)
#    bb.drawHorizLine(22, 30, 15, doubleStyle=true)
#    tb.setForegroundColor(fgCyan)
#    tb.write(bb)
#
#    tb.write(25, 17, fgWhite, "(7)")
#
#    # (8) TerminalBuffer.drawHorizLine/drawVertLine does connect
#    # overlapping lines by default
#    bb = newBoxBuffer(tb.width, tb.height)
#    bb.drawHorizLine(38, 50, 14, doubleStyle=true, connect=false)
#    bb.drawVertLine(40, 13, 15, doubleStyle=true, connect=false)
#    bb.drawVertLine(42, 13, 15, connect=false)
#    bb.drawVertLine(46, 13, 16, connect=false)
#    bb.drawHorizLine(40, 48, 15, doubleStyle=true, connect=false)
#    tb.setForegroundColor(fgMagenta)
#    tb.write(bb)
#
#    tb.write(43, 17, fgWhite, "(8)")
#
#    tb.write(0, 20,
#             "Check the source code for the description of the test cases ")
#
#    tb.display()
#
#    sleep(20)
#
#main()
#
