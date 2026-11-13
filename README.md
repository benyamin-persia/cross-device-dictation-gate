# Cross-Device Dictation Gate

**Use one mouse button for voice typing across Windows and macOS, without both computers listening at once.**

[![Build verification](https://github.com/benyamin-persia/cross-device-dictation-gate/actions/workflows/verify-build.yml/badge.svg)](https://github.com/benyamin-persia/cross-device-dictation-gate/actions/workflows/verify-build.yml)
![Windows](https://img.shields.io/badge/Windows-11-0078D4)
![macOS](https://img.shields.io/badge/macOS-supported-000000)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-experimental-orange)

Cross-Device Dictation Gate is an **open-source Windows + Mac companion** for people who share a keyboard and mouse through [Deskflow](https://github.com/deskflow/deskflow). It routes a configurable mouse button (tested with Logitech G502 **G6**) to **Windows Voice Typing** or **macOS Dictation**, depending on which computer the mouse is controlling.

It also attempts to stop the previous computer's Dictation when you switch screens. There is **no subscription, cloud server, account, or microphone recording** in the gate itself.

> **Project status: experimental.** The helpers build on both platforms and have been exercised on a Windows/Mac pair, but this is **not** a polished one-click installer for every machine. Audio routing, Deskflow, and macOS security permissions require separate setup. Windows Voice Typing pause detection is best-effort; see [Known limitations](#known-limitations).

## Contents

- [What it does](#what-it-does)
- [Before you install](#before-you-install)
- [Installation: step by step](#installation-step-by-step)
- [Optional: use the Windows microphone on the Mac](#optional-use-the-windows-microphone-on-the-mac)
- [Test your setup](#test-your-setup)
- [How it works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [Update and uninstall](#update-and-uninstall)
- [Security and privacy](#security-and-privacy)
- [Project layout](#project-layout)
- [Known limitations](#known-limitations)
- [Contributing](#contributing)

## What it does

| Your mouse is on… | Press G6 | After switching away |
|---|---|---|
| **Windows PC** | Activates or toggles Windows Voice Typing with `Win + H` | Attempts to **pause** Windows Voice Typing |
| **Mac / Mac mini** | Sends the Mac's custom Dictation shortcut, `Option + H` | Attempts to **stop** Mac Dictation |
| Disconnected/unknown | Does not intentionally trigger Dictation on the Mac | Waits for valid screen-status updates |

The goal: **one button, two computers, one active Dictation session**.

The Windows side uses the G6 button's existing **Win+H mapping**. When Deskflow is controlling the Mac, the Windows helper intercepts the local shortcut and sends a small LAN trigger to the Mac instead.

This project **does not modify Deskflow source code**, replace your mouse driver, or change your audio interface.

## Before you install

You need:

| Requirement | Windows PC | Mac |
|---|---|---|
| Operating system | Windows 11 | macOS with Swift compiler |
| Input sharing | **Deskflow server** | **Deskflow client** |
| Voice feature | Windows Voice Typing enabled | macOS Dictation enabled |
| Hotkey | G6 mapped to **Win+H** | Dictation shortcut set to **Option+H** |
| Build tools | PowerShell 5.1 + .NET Framework 4 C# compiler (`csc.exe`) | Xcode Command Line Tools (`swiftc`) |
| Connectivity | Same trusted LAN | Same trusted LAN |
| Other information | Deskflow screen name and readable server log | Mac screen name; macOS permissions |

**Supported layout:** Windows runs the Deskflow server and the Mac runs the client. Other combinations have not been packaged or tested.

**Important:** If you already run a custom Windows G6 interceptor or a Mac G6 Dictation helper, **disable the older helper before activating this new installation**. Running two keyboard hooks can duplicate shortcuts. The installer will not silently delete your existing helpers.

### Find the addresses and screen names

**On Windows**, open PowerShell and run:

```powershell
ipconfig
```

Find the active LAN IPv4 address, such as `192.168.1.10`. If Windows has multiple adapters, use the address of the adapter that can reach the Mac.

**On the Mac**, run:

```bash
ifconfig | grep 'inet '
```

Find its LAN IPv4 address, such as `192.168.1.20`, ignoring `127.0.0.1`.

In Deskflow, note the **exact screen names**, including capitalization. The Windows server usually has a log containing lines resembling:

```text
INFO: switch from "MY-PC" to "Mac"
INFO: switch from "Mac" to "MY-PC"
```

The default log path used by the Windows installer is `C:\ProgramData\Deskflow\deskflow-daemon.log`. Check the actual path on your computer.

The two IP addresses and screen names in this README are **examples**, not real installation defaults.

## Installation: step by step

### 1. Download the repository on both computers

[Download the latest source as a ZIP](https://github.com/benyamin-persia/cross-device-dictation-gate/archive/refs/heads/main.zip), or clone:

```bash
git clone https://github.com/benyamin-persia/cross-device-dictation-gate.git
```

Extract/open the directory on **both** computers. Nothing needs to be installed from the GitHub Actions workflow.

### 2. Configure Windows

Make sure Deskflow is running as **server** and its log is readable.

**Easy guided setup:** double-click `windows/Setup.cmd` in the extracted project folder. It asks you for the two IP addresses, screen names, and log path.

**Command-line setup** from PowerShell at the repository root:

```powershell
.\windows\install.ps1 -WindowsIp "192.168.1.10" -MacIp "192.168.1.20" -WindowsScreenName "MY-PC" -MacScreenName "Mac" -DeskflowLog "C:\ProgramData\Deskflow\deskflow-daemon.log"
```

The Windows installer:

1. Validates the supplied IPs, required files, and tools.
2. Generates configuration-specific source code from templates.
3. Compiles the Windows helper.
4. Installs it in `%LOCALAPPDATA%\CrossDeviceDictationGate`.
5. Registers the keyboard helper and Deskflow state watcher to start when **that user signs in**.

It does **not** uninstall or reconfigure Deskflow, Logitech G HUB, or other applications. It does not require making Windows Firewall globally permissive.

### 3. Configure the Mac

Make sure Deskflow is running as **client** and macOS Dictation is enabled.

Install Apple command-line build tools if necessary:

```bash
xcode-select --install
```

For guided setup, open Terminal in the downloaded repository and run:

```bash
bash macos/Setup.command
```

Or install directly with your actual IPs:

```bash
bash macos/install.sh --windows-ip "192.168.1.10" --mac-ip "192.168.1.20"
```

This builds a small local Swift app, signs it **ad hoc**, stores it in your user Applications folder, and installs a login LaunchAgent. The installer does **not** bypass macOS security prompts.

### 4. Approve macOS permissions

In **System Settings → Privacy & Security → Accessibility**, enable **Cross-Device Dictation Gate**. If macOS requests **Input Monitoring**, approve that too.

Set the **real** macOS Dictation shortcut in **System Settings → Keyboard → Dictation** to **Option+H**. Writing a preferences key alone is not enough.

If the helper was started before permission was granted, restart it from Terminal:

```bash
launchctl kickstart -k "gui/$(id -u)/org.crossdevice.dictationgate"
```

You may need to reapprove permissions when you rebuild or replace an ad-hoc signed app.

### 5. Confirm G6 mapping

In the Windows mouse software, set **G6** to the keyboard shortcut **Win+H**. Do not assign a separate Mac shortcut in that software.

Deskflow will share the physical key events, and the gate will decide which machine should respond.

## Optional: use the Windows microphone on the Mac

**The gate sends control events, not audio.** If your microphone is physically plugged into Windows, you will need an audio route for Mac Dictation.

One optional, free setup:

```text
USB microphone / Focusrite on Windows
           │
           ▼
     SonoBus on Windows (send)
           │  LAN audio
           ▼
     SonoBus on Mac (receive)
           │
           ▼
        BlackHole 2ch
           │
           ▼
      macOS Dictation
```

Install [SonoBus](https://sonobus.net/) on both machines and [BlackHole](https://existential.audio/blackhole/) on Mac. In SonoBus on Mac, choose BlackHole 2ch as **output**; in macOS Dictation, choose BlackHole 2ch as the **microphone input**.

First confirm that audio reaches the Mac and that **Option+H works without G6**. Only then test mouse-button routing.

See the detailed [audio guide](docs/audio.md). SonoBus and BlackHole are independent third-party projects and are **not automatically installed** by these scripts.

## Test your setup

Use a **blank text document** on each computer, not an important unsaved file.

- [ ] Windows: press G6. Windows Voice Typing opens and captures speech.
- [ ] Move the mouse to Mac. Windows Voice Typing pauses.
- [ ] On Mac: press G6. macOS Dictation starts.
- [ ] Move back to Windows. Mac Dictation stops.
- [ ] On Windows: press G6 again. Voice Typing works without a lengthy reinitialization.
- [ ] Switch back and forth several times and ensure the two computers do not both transcribe.

**If Windows Voice Typing stays active or toggles the wrong way, use its microphone control manually.** The current implementation infers Dictation state from G6 presses and cannot always distinguish a session started or stopped by another mechanism.

### Build without installing

To check whether your machine can compile the app, without creating startup tasks or replacing an active helper:

**Windows:**

```powershell
.\windows\install.ps1 -WindowsIp "10.20.30.10" -MacIp "10.20.30.20" -WindowsScreenName "WIN" -MacScreenName "MAC" -ValidateOnly
```

**Mac:**

```bash
bash macos/install.sh --windows-ip "10.20.30.10" --mac-ip "10.20.30.20" --validate-only
```

These example addresses are intentionally nonfunctional; validation checks source generation and compilation only.

The same checks run in [GitHub Actions](https://github.com/benyamin-persia/cross-device-dictation-gate/actions/workflows/verify-build.yml) for Windows and macOS.

## How it works

```text
                 Windows (Deskflow server)
                   │
   Deskflow switch log ──────────┐
                   │             │
            State watcher        │
                   │             │
             LAN state ──────────┼────────► Mac (Deskflow client)
                   │             │             │
            Windows G6 gate      │       macOS Swift gate
                   │             │             │
        ┌──────────┴───────┐     │         Option+H
        │                  │     │             │
     On Windows         On Mac  └────────► macOS Dictation
        │                  │
     Win+H            LAN trigger
        │                  │
   Windows Voice           └────────────► Mac gate
      Typing
        │
    Pause on switch to Mac
    (do not kill TextInputHost)
```

The Windows state watcher reads the existing Deskflow log and sends a small UDP message. The Windows app runs a low-level keyboard hook **in the signed-in user's session**. The Mac app uses a Quartz keyboard event tap and a per-user LaunchAgent.

There is no hosted service, recurring subscription, or separate transcription engine.

See [architecture and protocol details](docs/architecture.md).

## Troubleshooting

| Symptom | What to check |
|---|---|
| G6 triggers both systems | Ensure only one copy of each G6 helper is running; remove conflicts from older custom setups |
| Mac Dictation will not start | macOS Accessibility and Input Monitoring, correct **Option+H** shortcut |
| No words appear on Mac | Check SonoBus receive audio, BlackHole output, and Dictation microphone selection |
| Mac does not recognize switches | Correct Windows/Mac LAN IPs, port, exact Deskflow screen names and readable Deskflow log |
| Windows Voice Typing returns slowly | Check whether another script is **terminating TextInputHost.exe**; this project's current code does not do so |
| Windows continues listening on Mac | The Windows pause toggle may be out of sync; use Voice Typing's mic button and inspect the gate log |
| Gate stops working after restart | Check per-user startup entries; approve Mac privacy permissions again if necessary |

**Windows diagnostics:**

```powershell
Get-Process WindowsVoiceGate,TextInputHost -ErrorAction SilentlyContinue
Get-Content "$env:LOCALAPPDATA\CrossDeviceDictationGate\G6WindowsVoiceGate.log" -Tail 30
Get-Content "$env:LOCALAPPDATA\CrossDeviceDictationGate\G6-switch-sender.log" -Tail 30
```

**Mac diagnostics:**

```bash
launchctl print "gui/$(id -u)/org.crossdevice.dictationgate"
tail -30 "$HOME/Library/Application Support/CrossDeviceDictationGate/gate.log"
tail -30 "$HOME/Library/Application Support/CrossDeviceDictationGate/gate-error.log"
```

Read the [full troubleshooting guide](docs/troubleshooting.md).

## Update and uninstall

### Update

Download the latest version on both computers. To replace an existing **installation of this package** (backing up its previous package files):

**Windows:** rerun `windows/Setup.cmd` and approve the update, or supply `-Update` to `windows/install.ps1`.

**Mac:** rerun `bash macos/Setup.command` and approve the update, or supply `--update` to `macos/install.sh`.

Updating may trigger new macOS Accessibility authorization because the app is ad-hoc signed.

### Uninstall

**Windows** (from repository root):

```powershell
.\windows\uninstall.ps1
```

**Mac** (from repository root):

```bash
bash macos/uninstall.sh
```

By default, uninstall removes this project's startup and active helpers but preserves package logs/backups. To remove all of this package's local files, add `-RemoveFiles` on Windows or `--remove-data` on Mac.

**These commands do not uninstall Deskflow, Logitech software, SonoBus, BlackHole, or your earlier custom helpers.**

## Security and privacy

- The app does **not** capture, save, or upload voice recordings.
- It reads the **local Deskflow server log** to identify active screens.
- Small control messages are sent **between your own computers on your LAN** using UDP (default port **43891**).
- **Current LAN messages are not cryptographically authenticated.** The Mac filters by a configured Windows IP, but IP filtering alone is insufficient on an untrusted network. Use only a trusted LAN. **Never port-forward the port.**
- Do not publish personal installer configuration, microphone recordings, logs, or screenshots containing sensitive information.
- The installers have scoped installation directories. They do not disable system security controls or remove unrelated software.
- Both macOS and Windows helpers use sensitive input hooks; review the source before installing and never grant OS permissions you do not understand.

## Project layout

```text
.github/workflows/verify-build.yml   Windows + Mac build checks
windows/Setup.cmd                     Guided Windows setup launcher
windows/Setup.ps1                     Guided configuration questions
windows/install.ps1                   Build/install/autostart
windows/uninstall.ps1                 Remove package
windows/WindowsVoiceGate.cs.in        Windows C# helper source template
windows/SwitchSender.ps1.in           Deskflow switch-state watcher
macos/Setup.command                   Guided Mac setup launcher
macos/install.sh                      Build/sign .app and LaunchAgent
macos/uninstall.sh                    Remove package
macos/MacDictationGate.swift.in       Mac Swift helper source template
docs/architecture.md                 Design, protocol and limitations
docs/audio.md                        Optional SonoBus + BlackHole setup
docs/troubleshooting.md              Diagnostics and rollback
LICENSE                              MIT License
```

## Known limitations

This is a **community experiment**, not a finished universal voice-typing product.

1. It supports a **Windows Deskflow server + Mac client** configuration; other arrangements are untested.
2. Windows Dictation stop is a **best-effort Win+H toggle**, based on tracked G6 presses. Manually activating or pausing Voice Typing can put the helper's internal state out of sync.
3. The Mac's Dictation stop operation is best-effort because its HUD and behavior vary by macOS version.
4. Deskflow's log format and screen identifiers may change.
5. New IP addresses require updating configuration.
6. macOS may prompt again for permissions after a reinstall/update.
7. **Fresh machine installation has not been fully end-to-end tested.** Passing compilation and CI checks confirms the source builds, not that speech recognition and mouse routing work on every system.

Please open an issue with the Windows/macOS version, Deskflow version, audio route, symptom, and **redacted** logs when reporting bugs.

## Contributing

Contributions and issue reports are welcome. Especially useful improvements: reliable speech-state detection, authenticated LAN messages, device discovery, automated smoke tests, packaging/signing, and additional keyboard-sharing software support.

- Fork the project.
- Make a focused change and explain what it fixes.
- Run both validation commands or confirm CI passes.
- Open a pull request with reproducible testing steps.

The code is released under the **[MIT License](LICENSE)**.

---

Built for people who switch between Windows and macOS all day and would prefer that Dictation not follow them around like a haunted microphone.
