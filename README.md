# CC: Tweaked Control

## Local Hosting

Edit the `computercraft-server.toml` and comment out these lines - [guide](https://tweaked.cc/guide/local_ips.html)

```toml
# [[http.rules]]
	# host = "$private"
	# action = "deny"
```

## Server Startup

1. Start web interface

   ```bash
   cd server/interface
   pnpm dev
   ```

2. Start websocket server

   ```bash
   cd server
   pnpm dev
   ```

## Game Setup

1. Build a gps system (preferably with ender modems) - [guide](https://tweaked.cc/guide/gps_setup.html)

2. Build the configuration as below, where

   ```css
   T = Mining Turtle
   D = Disk Drive (with floppy disk inside)
   C = Computer
   ~~~
   T
   D C
   ```

3. In the `computer`, run the following command

   ```sh
   pastebin get uGKYiRKb disk/startup/install.lua
   ```

4. Open the turtle, and provide it with an `ender modem` in the first inventory slot

5. Open the `turtle`, and type the command

   ```sh
   reboot
   ```
