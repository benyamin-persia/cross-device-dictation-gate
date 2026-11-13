# Architecture and protocol

## What is controlled

The helper coordinates **keyboard shortcuts and Dictation state**. It does not perform transcription, capture audio, or forward the microphone. SonoBus/BlackHole are separate audio components.

- **Deskflow** shares mouse and keyboard. Its server log includes messages of the form \`INFO: switch from "SCREEN_A" to "SCREEN_B"\`.
- The **Windows sender** watches that existing log (polling around 200 ms), determines the active screen, and sends the corresponding state to the Mac.
- The **Windows gate** installs a low-level keyboard hook in the user's interactive Windows session. It normally lets \`Win+H\` reach Windows Voice Typing. When the mouse controls the Mac, it consumes the local \`Win+H\` and sends a trigger to the Mac instead.
- The **Mac gate** listens on the configured UDP port and uses a Quartz event tap to emit Option+H only when the active screen is the Mac. It attempts to stop Mac Dictation with Escape on a switch to Windows.
- When switching from Windows to Mac, the Windows helper attempts to pause a **tracked, listening** voice-typing session using a synthetic Windows-local \`Win+H\` toggle. It deliberately does not kill \`TextInputHost.exe\`.

## Protocol

All messages are short UTF-8 datagrams sent over UDP.

| Message | Origin | Meaning |
|---|---|---|
| \`G6_CONTROL_WIN\` | Windows sender | Windows controls mouse/keyboard |
| \`G6_CONTROL_MAC\` | Windows sender | Mac controls mouse/keyboard |
| \`G6_REMOTE_TRIGGER\` | Windows gate | Trigger macOS Dictation on a G6 press while controlling Mac |
| \`G6_GATE_ALIVE\` | Windows gate | Additional heartbeat; Mac recognizes the Windows-side gate |

The Mac side currently filters packets by **source IP**, but this is not cryptographic authentication. Stay on a trusted LAN only. Never open the UDP port to the internet. Contributions adding a shared-secret HMAC and replay protection are welcome.

## Configuration

Windows installer substitutions:

- \`__WINDOWS_IP__\`: LAN IPv4 source of the Windows Deskflow server
- \`__MAC_IP__\`: LAN IPv4 address of Mac mini
- \`__WINDOWS_SCREEN_NAME__\`, \`__MAC_SCREEN_NAME__\`: exact Deskflow screen names
- \`__DESKFLOW_LOG_PATH__\`: full path of server log
- \`__UDP_PORT__\`: chosen LAN UDP port

macOS installer substitutions: Windows IP and UDP port. The Mac IP is supplied for configuration documentation and diagnostics.

The Windows gate's state comes from the sender log in \`%LOCALAPPDATA%\CrossDeviceDictationGate\G6-switch-sender.log\`. The sender is registered in HKCU's Run key. The Mac runs via a per-user LaunchAgent (\`org.crossdevice.dictationgate\`) and a signed local app bundle.

## Recovery

Power loss, laptop sleep, Deskflow disconnect, or IP changes can leave state temporarily unknown. The Mac gate uses a heartbeat timeout to avoid activating Dictation on the wrong machine. If it fails closed, restart the sender or reconnect Deskflow. Do not repeatedly click G6 while waiting for recovery.

## Known platform limitations

1. A Windows \`Win+H\` toggle is not a direct Windows speech API, and the helper infers whether it is on from intercepted presses. A Voice Typing session started manually, paused from its toolbar, or affected by focus changes can desynchronize this inference.
2. Synthetic Win+H may be intercepted by keyboard sharing tools or Windows security contexts. This is currently a best-effort approach; a future Windows-specific Voice Typing API/UIA integration could improve reliability.
3. macOS permissions are bound to an app's signing identity and may need reapproval after upgrades.
4. A low-level keyboard hook is desktop-user-scoped; Windows Session 0 services and elevated windows may behave differently.
5. This project was adapted from one pair of computers and **must be tested separately on each new Deskflow, Windows and macOS version**.

## Safe design choices

Installers use a **different application name and folder** from historical local helpers. They never edit an existing G HUB profile, change macOS TCC databases, disable the OS firewall, or delete other programs. Source is intentionally provided as templates so no actual user's machine names/IPs are committed.
