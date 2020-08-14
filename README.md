# MahjongEnvironment
This is an implementation of Chengdu Mahjong fully written in Julia. It provides interface for game playing using WebSockets.

There is no graphical UI for the game currently. The game environment is used for training AI Mahjong agents, see the project in this repository: <https://github.com/coldinjection/ReinforcedMahjong>

## Installation
Press `]` to enter the package manager and do:

```
add https://github.com/coldinjection/MahjongEnvironment.git
```

## Run a game server
To run a game server (or a Hall) that listens to 127.0.0.1:8080, do:
```
using MahjongEnvironment
hall = Hall(); # or specify ip and port: Hall(ip::String, port::Int)
@async serve_hall(hall)
```
Visiting 127.0.0.1:8080 in a browser will then return the debugging UI which is basically one screen shared by 4 players.
