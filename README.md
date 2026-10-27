# Sony Connect

A small menu bar app for controlling Sony WH-1000XM6 headphones from a Mac, so you don't have to reach for your phone and the Sound Connect app every time you want to switch to ambient sound or change the EQ.

It talks to the headphones directly over Bluetooth using the same protocol the phone app uses. No account, no internet, nothing running in the background apart from the menu bar icon.

I've only tested it with my own XM6 (firmware 3.1.5) on macOS 27. Other Sony headphones that work with Sound Connect might partly work, but I haven't tried any.

## What it does

- Noise cancelling, ambient sound or off, with the ambient level and Focus on voice
- Listening mode: Standard, Background music (with My room, Living room and Café) and Cinema
- Volume
- Live sound level in dB from the headphones' own sensor
- DSEE Extreme and Speak-to-chat on and off
- Equalizer: the built-in presets, your custom presets, the 10-band editor and Clear Bass
- Shows which of your devices are connected, lets you move playback to another one or disconnect it, and has the Keep playback here option
- Battery level in the menu bar panel
- Reconnects on its own when the headphones come back, and reopens the connection if the headphones stop responding
- Optional open at login

## Installing

You need a Mac with Apple silicon running macOS 14 or later. On an Intel Mac, build it yourself (see below).

1. Download `Sony-Connect.zip` from the [latest release](../../releases/latest) and unzip it.
2. Move `Sony Connect.app` to your Applications folder.
3. Open it. macOS will refuse, because the app isn't signed with an Apple developer certificate. Click **Done**.
4. Open **System Settings › Privacy & Security**, scroll down to the message about Sony Connect and click **Open Anyway**, then confirm with your password.

If you'd rather use Terminal, this does the same as steps 3 and 4:

```sh
xattr -dr com.apple.quarantine "/Applications/Sony Connect.app"
```

The first time it runs, macOS asks whether Sony Connect can use Bluetooth. Say yes, otherwise it can't reach the headphones.

The headphones need to be paired and connected to the Mac as usual. The app finds them by itself; look for the headphones icon in the menu bar.

## Building it yourself

You only need Apple's command line tools, not the full Xcode:

```sh
xcode-select --install
```

Then:

```sh
git clone https://github.com/rayjaywolf/sony-connect.git
cd sony-connect
./build.sh
open ~/Applications/"Sony Connect.app"
```

`build.sh` compiles a release build, puts the app in `~/Applications` and signs it locally, so macOS doesn't block it the way it blocks a downloaded copy. Run it again after pulling changes. macOS may ask for Bluetooth permission again after a rebuild.

## Troubleshooting

**The panel says it can't reach the headphones.** Make sure they're connected to the Mac in System Settings › Bluetooth, then press Connect. If the Sound Connect app is open on your phone, close it. The headphones only allow one controller at a time.

**A setting doesn't change.** The app reopens the connection when the headphones stop answering, which takes a few seconds. If it keeps happening, the log will show what's going on:

```sh
log show --info --last 10m --predicate 'subsystem == "com.rayjay.xm6control"'
```

**Bluetooth permission was denied.** Turn it on in System Settings › Privacy & Security › Bluetooth.

## Notes

This isn't made by or affiliated with Sony. Sony, WH-1000XM6 and DSEE Extreme are trademarks of Sony Group Corporation.

The protocol details came from looking at the traffic between the headphones and the phone app, along with [sony-xm6-web](https://github.com/andersnsouza/sony-xm6-web).
