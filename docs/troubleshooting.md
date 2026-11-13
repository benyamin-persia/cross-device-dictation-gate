# Troubleshooting and verification

## What should happen

| Test | Expected |
|---|---|
| G6 on Windows | Voice Typing opens with `Win+H` |
| Move to Mac | Windows Voice Typing pauses; Windows Input Experience process stays alive |
| G6 on Mac | Mac Dictation activates using configured Option+H |
| Move back to Windows | Mac Dictation stops; Windows Voice Typing stays available without a lengthy process restart |
| Rapid 4× switching | No `TextInputHost.exe` crashes or restarts |

**An installed service is not proof that the complete microphone workflow works.** Test dictation with a blank text editor.

## Windows diagnostics

Open a new PowerShell window:

```powershell
Get-Process WindowsVoiceGate -ErrorAction SilentlyContinue
Get-Process TextInputHost -ErrorAction SilentlyContinue | Select-Object Id, StartTime
Get-Content "$env:LOCALAPPDATA\CrossDeviceDictationGate\G6WindowsVoiceGate.log" -Tail 30
Get-Content "$env:LOCALAPPDATA\CrossDeviceDictationGate\G6-switch-sender.log" -Tail 30
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
```

Check whether Deskflow writes switch lines to the file specified during installation. If its server log moved, rerun the installer with the correct `-DeskflowLog` and `-Update`.

If Windows Voice Typing takes several seconds to return, check if `TextInputHost.exe` has a **new start time** after a switch. The current gate must not issue WM_CLOSE or kill the host.

If Windows speech remains active after a switch, the best-effort Win+H pause may have lost track of its state. Use Windows Voice Typing's microphone button to pause manually, then try G6 again. A future improvement should use supported Windows speech state APIs rather than inferring from keypresses.

## Mac diagnostics

```bash
launchctl print "gui/$(id -u)/org.crossdevice.dictationgate"
tail -30 "$HOME/Library/Application Support/CrossDeviceDictationGate/gate.log"
tail -30 "$HOME/Library/Application Support/CrossDeviceDictationGate/gate-error.log"
lsof -nP -iUDP:43891
```

If `ERROR_NO_EVENT_TAP` appears: open **System Settings → Privacy & Security → Accessibility** and enable **Cross-Device Dictation Gate**. Grant Input Monitoring if requested. Restart the helper:

```bash
launchctl kickstart -k "gui/$(id -u)/org.crossdevice.dictationgate"
```

When Option+H types a character rather than starting Dictation, the Mac's **real** Dictation keyboard setting is not configured to Option+H; changing the old preferences file alone is insufficient.

## Duplication and conflicts

Do not run both the **old G6Dictation helper** and this new gate on the same Mac. They can both intercept the button and trigger Dictation twice. Disable/stop the old helper first, after you have backed it up.

Likewise, do not run two Windows keyboard hooks from two different versions simultaneously. This project has its own names and folders to avoid silently overwriting an older installation.

## Privacy and network security

Only use the UDP port on a trusted LAN. The protocol currently relies on a configured Windows IP (not cryptographic authentication). Never port-forward it.

## Rollback

```powershell
.\windows\uninstall.ps1
```

```bash
./macos/uninstall.sh
```

Uninstall preserves local logs/backups unless `-RemoveFiles` (Windows) or `--remove-data` (Mac) is explicitly provided. It does not uninstall the OS input service or third-party audio applications.
