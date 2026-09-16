# Pasteback

A minimal, local-first clipboard history utility for macOS 14+.

macOS keeps one clipboard slot. Pasteback remembers recent clipboard items on
this machine only, so an accidental copy no longer destroys the previous one,
and nothing sticks around longer than you want.

- Menu bar app (no Dock icon)
- Plain text, rich text (as plain text), URLs, images, file references
- Search, pin, delete, restore to clipboard
- Global hotkey (default ⌃⇧⌘C) opens the panel
- Everything encrypted at rest with AES-256-GCM; key lives in the Keychain
- Retention: unpinned items expire (text 1 h, images/files 1 d by default);
  likely secrets (tokens, API keys, card numbers) expire in seconds
- No cloud, no accounts, no analytics, no telemetry, no network use except
  user-initiated update checks

## Build

Requires the Swift 6 toolchain (Xcode or Command Line Tools) on macOS 14+.

    make build          # swift build -c release
    make app            # release build + dist/Pasteback.app bundle (icon, Sparkle, adhoc signature)

`make app` produces `dist/Pasteback.app`. Copy it to /Applications for normal
use. The app is adhoc-signed; for distribution, re-sign with a Developer ID
certificate.

Note for Command Line Tools (no full Xcode): the SwiftUI macro plugin is not
shipped with CLT, so the UI avoids SwiftUI state property wrappers (`@State`
and friends) and uses `ObservableObject` models plus small AppKit wrappers.
Full Xcode is not required.

## Run

    make run            # dev build directly from the CLI
    open dist/Pasteback.app

Pasteback shows a clipboard icon in the menu bar. Click it (or press the
hotkey) for the history panel. Clicking an item writes it back to the
clipboard; press ⌘V in the target app to paste.

## Tests

    make test

(On CLT installs this loads the Swift Testing macro plugin explicitly; see the
Makefile.) 55 tests cover pasteboard capture/classification/restore, storage
dedupe/limit/expiry, encryption (on-disk ciphertext, round-trip, wrong key,
Keychain), retention per kind + sensitive + pinned, sensitive detection, and
hotkey registration/change/conflict handling.

## Where data lives

- History: `~/Library/Application Support/Pasteback/History.store` — one
  AES-256-GCM encrypted file (`PBST` header + version + sealed box). Not
  readable without the Keychain key. Settings → “Open Storage Folder”.
- Encryption key: a 256-bit key in the login Keychain
  (service `com.pasteback.encryption`, account `history-key`,
  `AfterFirstUnlockThisDeviceOnly`).
- Preferences: `~/Library/Defaults` via `NSUserDefaults` (key prefixes
  `pasteback.*`) — no clipboard content, only counts/intervals/toggles.
- Update-signing private key (maintainer): login Keychain, service
  `https://sparkle-project.org`, account `ed25519` (same item Sparkle's own
  tools use).

## Privacy behavior

- Clipboard payloads never leave the machine and are never written to disk in
  plaintext — including previews (the whole record is encrypted).
- Clear All wipes the store file.
- No network traffic at runtime except Sparkle update checks, which are
  strictly user-initiated (“Check for Updates…”; `SUEnableAutomaticChecks` is
  false). Update checks send no clipboard data.
- Likely secrets copied to the clipboard expire after 30 seconds by default
  (configurable) and are removed automatically.
- Launch at login uses `SMAppService` (visible in System Settings → Login
  Items; revocable there).

## Software updates

Sparkle 2 is integrated with a placeholder appcast and user-controlled checks
only. Until a real feed exists, the build bundles `docs/appcast.xml` into the
app and points `SUFeedURL` at that bundled `file://` path, so “Check for
Updates…” cleanly reports “up to date”. The `file://` URL is absolute; if you
move `Pasteback.app`, rebuild (`make app`) or wait for the real feed. To ship
updates: run `make keys` (stores the ed25519 private key in your login
Keychain, prints the public key — committed at `Resources/SparklePublicED.key`),
host the appcast somewhere real, set that URL as `SUFeedURL` in
`scripts/Resources/App-Info.plist`, and sign each release with Sparkle's
`sign_update`.

## Settings

Launch at login · global hotkey (recordable; conflicts reported) · maximum
stored items · expiration for text / images / file references · sensitive-item
expiration · open storage folder · clear all items.

## Architecture

    Sources/PastebackCore/          all non-UI logic; protocols for testability
      Models/                       ClipboardItem, ItemKind, ItemPayload
      Pasteboard/                   Pasteboarding protocol, SystemPasteboard
                                    (classify/write), ClipboardMonitor (polling)
      History/                      ClipboardHistory (dedupe, limit, pin, expiry)
      Storage/                      EncryptedHistoryStore, DataFileStoring,
                                    KeychainStoring
      Crypto/                       AESGCMEncryptionService (CryptoKit)
      Retention/                    RetentionService (sweep timer)
      Sensitive/                    SensitiveDetector (JWT/API-key/card heuristics)
      Hotkey/                       HotkeyCenter + Carbon registrar (no
                                    Accessibility permission needed)
      Settings/                     AppSettings (NSUserDefaults-backed)
      Login/                        SMLoginItem (SMAppService)
      Support/                      DateProviding clock, os.Logger namespaces
    Sources/Pasteback/              thin UI: status item + popover, settings
                                    window, view models, AppKit representables

Deliberate deviations:
- **NSStatusItem + NSPopover instead of SwiftUI MenuBarExtra.** The global
  hotkey must open the panel programmatically; MenuBarExtra has no API for
  that. AppKit is sanctioned for native needs and this is the standard
  approach for menu bar utilities.
- Restore writes to the clipboard only; no simulated ⌘V (that would need
  Accessibility permission).

## Verification performed

- `swift build` (debug + release) and `swift test` green.
- End-to-end on this machine: launched `dist/Pasteback.app`, wrote items to
  the pasteboard via the NSPasteboard API, confirmed the encrypted store grew,
  contained no plaintext, and decrypted correctly with the Keychain key.
- UI (panel click-through) was not driven programmatically (no accessibility
  permission in the build environment); restore behavior is covered by unit
  tests against real `NSPasteboard` instances.

## License

MIT — see [LICENSE](LICENSE).
