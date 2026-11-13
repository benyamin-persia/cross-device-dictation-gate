# Cross-Device Dictation Gate

A **free, source-available Windows + macOS helper** for people who use [Deskflow](https://github.com/deskflow/deskflow) to share one keyboard and mouse between two computers, and want a mouse button to activate voice typing **only on the computer currently being controlled**.

This project packages an existing, locally tested configuration into repeatable installers. **It is experimental software, not a fully unattended universal installer.** macOS Accessibility and Input Monitoring permissions require the user's approval, and audio device selection in third-party apps may still need manual setup.

## Behavior

| Active Deskflow screen | G6 action | On switch away |
|---|---|---|
| Windows | Windows Voice Typing (`Win+H`) | Attempt to pause, **without killing TextInputHost** |
| Mac | macOS Dictation (custom `Option+H`) | Stop the Mac Dictation session |
| Unknown / disconnected | No Mac remote activation | Do not forward a new Mac trigger |

G6 can remain assigned to **Win+H** in the mouse's Windows software. The Windows helper intercepts it while Deskflow controls the Mac and sends a separate LAN trigger instead. On the Mac, the helper also handles forwarded Deskflow Command+H from earlier mouse layouts.

## Requirements

- Windows 11 with PowerShell 5.1, .NET Framework 4.x C# compiler (`csc.exe`) and Deskflow in **server** mode.
- macOS with `swiftc` and Deskflow in **client** mode. Xcode Command Line Tools can supply `swiftc`.
- Both computers on a trusted LAN, with fixed/reserved LAN addresses or a way to update the configuration when addresses change.
- A mouse G6 button mapped to `Win+H` on Windows.
- macOS Dictation enabled and its keyboard shortcut set to **Option+H** (in System Settings → Keyboard → Dictation).
- Permission to read the Deskflow server log file.
- Optional microphone streaming: [SonoBus](https://sonobus.net/) on both systems and [BlackHole](https://existential.audio/blackhole/) on Mac.

**No cloud AI service, paid subscription or microphone recording** is required by the gate itself.

## Quick installation

**Guided setup:** on Windows, run `windows/Setup.cmd`. On Mac, run `chmod +x macos/Setup.command && ./macos/Setup.command` from a terminal. These launchers ask for your actual LAN IPs and Deskflow screen names. You can also use the noninteractive commands below for repeated installations.

1. Clone or download this repository on **both computers**.
2. Install/configure Deskflow first, then note the Windows screen name, Mac screen name, and both LAN IPs.
3. On the Mac, run:
   ```bash
   cd macos
   chmod +x install.sh uninstall.sh
   ./install.sh --windows-ip 192.168.1.10 --mac-ip 192.168.1.20
   ```
4. On Windows, open PowerShell in the repository and run:
   ```powershell
   .\windows\install.ps1 -WindowsIp 192.168.1.10 -MacIp 192.168.1.20 -WindowsScreenName "MY-PC" -MacScreenName "Mac" -DeskflowLog "C:\ProgramData\Deskflow\deskflow-daemon.log"
   ```
5. On the Mac, open **System Settings → Privacy & Security → Accessibility**, allow **Cross-Device Dictation Gate**, then restart its LaunchAgent if prompted:
   ```bash
   launchctl kickstart -k "gui/$(id -u)/org.crossdevice.dictationgate"
   ```
6. Verify the **Input Monitoring** permission if macOS requests it. Then test with a blank text editor on each computer. Do not test inside an important unsaved document.

Use your actual IPs and names; values above are examples only. Windows Firewall may need a LAN-scoped inbound exception for the Mac's UDP receive port. The gate installer never disables or broadly opens the system firewall. Approve the local LAN receiver if macOS requests it.

## Audio routing (optional and separate)

The gate **does not send microphone audio**. If your physical microphone is attached to Windows and you want to dictate on the Mac:

```
Windows microphone → SonoBus (send) → SonoBus on Mac (receive) → BlackHole 2ch → macOS Dictation
```

SonoBus and BlackHole are third-party projects. Select your actual input on Windows, select BlackHole as the **receive/output device on Mac**, and select BlackHole as Dictation's microphone source. Test levels before troubleshooting G6. See [docs/audio.md](docs/audio.md).

## Design

```text
Windows (Deskflow server)                 Mac (Deskflow client)
  Deskflow switch log
          │
  SwitchSender.ps1 (poll)
          │ UDP: control state
          ├───────────────────────────────► MacDictationGate (Swift)
          │                                 ├─ G6 -> Option+H
  WindowsVoiceGate (C#) ── UDP: trigger ────►├─ handles macOS dictation
          ├─ keyboard hook                  └─ stops on switch to Windows
          ├─ G6 on Windows → Win+H
          └─ pause on switch to Mac
```

There is **no permanently running cross-platform privileged daemon**. Both helpers run in the signed-in user's GUI session. The Windows process must not run as a service in Session 0, otherwise its keyboard hook will not see normal desktop input.

## Files

- `windows/WindowsVoiceGate.cs.in`: Windows keyboard hook and voice typing gate template.
- `windows/SwitchSender.ps1.in`: Deskflow log watcher and state broadcast template.
- `windows/install.ps1`: parameterized Windows installer and startup registration.
- `windows/uninstall.ps1`: removes this project's autostart and processes, optionally its installed files.
- `macos/MacDictationGate.swift.in`: macOS event tap and receiver template.
- `macos/install.sh`: builds and signs a local app, creates LaunchAgent.
- `macos/uninstall.sh`: removes this project's LaunchAgent/app; keeps unrelated settings.
- `docs/architecture.md`, `docs/audio.md`, `docs/troubleshooting.md`: technical details and diagnostics.

## Safety, privacy, and limitations

- Source templates do not contain actual names, hostnames, passwords, private network addresses or credentials.
- The experimental LAN protocol accepts messages from a **configured Windows IP**. It is **not cryptographically authenticated**; use it only on a trusted LAN, never over the public internet, and do **not** port-forward the receiver. For untrusted networks, add message authentication and a VPN.
- macOS may require explicit Accessibility/Input Monitoring approval after installation or updates. Install scripts cannot bypass these permissions.
- Deskflow log message format may change across versions. This project reads the server log rather than an official switch-state API.
- The Windows pause behavior is a best-effort `Win+H` toggle, based on tracked G6 presses. It can lose synchronization if Voice Typing is started from another shortcut/control or a switch occurs mid-transition. It intentionally **does not kill TextInputHost**.
- The Mac Dictation HUD varies across macOS versions; stop behavior is also best-effort.
- Static UDP ports and IPs are installer-configurable; changing your LAN addresses requires rerunning setup.
- The installer makes backups where it modifies its own installed files and never deletes arbitrary existing user code.

## Verification status

The source was extracted from a working Windows/Mac pair and converted into templates. The original installation has been tested on that pair. **The clean install workflow and every platform/version combination still require testing on new machines.** A compiled helper does not prove that a real mic session starts/stops correctly; test the actual mouse and microphone end-to-end.

## Uninstall

On Windows:
```powershell
.\windows\uninstall.ps1
```
On Mac:
```bash
./macos/uninstall.sh
```

By default, uninstall preserves app logs/config for inspection. It does not uninstall SonoBus, Deskflow, BlackHole or the user's existing programs.

## License

MIT. See [LICENSE](LICENSE).
