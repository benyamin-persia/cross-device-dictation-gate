# Optional microphone routing: Windows to Mac

The Cross-Device Dictation Gate controls **keyboard shortcuts**, not microphone capture. A microphone physically connected to Windows can be supplied to macOS Dictation by routing it through third-party audio tools.

## Required applications

- **SonoBus** on Windows and Mac: https://sonobus.net/
- **BlackHole 2ch** on Mac: https://existential.audio/blackhole/
- **Deskflow** already working for keyboard/mouse sharing: https://github.com/deskflow/deskflow

## Suggested flow

1. Plug the microphone/audio interface into Windows, verify that its meter moves in Windows sound settings.
2. Open SonoBus on Windows. Select that physical microphone as input. Join a **private group**.
3. Open SonoBus on Mac, join the same group, and receive the Windows peer.
4. On Mac, choose **BlackHole 2ch** as the SonoBus output device. Do not select BlackHole as the Mac's microphone source for *sending back* unless intentionally loopback streaming.
5. In macOS **System Settings → Keyboard → Dictation**, choose **BlackHole 2ch** as microphone input and enable Dictation. Configure the Dictation shortcut as **Option+H**.
6. Verify that the BlackHole input meter moves on the Mac *before* checking G6.
7. Turn off SonoBus local monitoring if it makes you hear your own voice through your Mac speakers.

Audio transfer is independent of the keyboard/mouse screen status. Both SonoBus processes can stay connected while you switch computers.

## Windows Firewall

If SonoBus shows a peer but reports `Other side is muted` / `0ch` despite a moving input meter, test whether Windows Firewall blocks inbound local UDP traffic for SonoBus.

For local-network safety, allow **only SonoBus.exe**, only inbound **UDP**, only from the Mac's LAN IP, and only on the needed local profiles. This may require administrator approval. Never disable the entire firewall as a workaround.

This project's Dictation Gate uses a separate UDP port for control messages (default **43891**). An outbound Windows-to-Mac packet usually does not require a Windows inbound rule. If macOS firewall blocks the Mac helper, approve the helper in System Settings.

## Troubleshooting order

1. Windows physical microphone receives audio.
2. SonoBus Windows *send meter* moves.
3. SonoBus Mac *receive meter* moves and shows audio channels.
4. BlackHole meter on Mac moves.
5. macOS Dictation works using **Option+H on the Mac keyboard**.
6. Only after all of the above, test G6 on both systems.

Mac security permission prompts can block the gate from sending synthetic shortcuts, but they do not indicate a SonoBus audio problem.

No voice audio is collected by the Gate source code or uploaded to GitHub.
