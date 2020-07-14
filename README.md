# MahjongEnvironment
This is an implementation of Chengdu Mahjong.

## Installation
Press `]` to enter the package manager and do:

```
add https://github.com/coldinjection/MahjongEnvironment.git
```

## Run a game server
To run a game server (or a Hall) that listens to 127.0.0.1:8080:
```
using MahjongEnvironment
hall = Hall() # or specify ip and port: Hall(ip::String, port::Int)
@async serve_hall(hall)
```