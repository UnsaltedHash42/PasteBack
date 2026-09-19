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
- Command line access: `pasteback list` / `pasteback get` work like `pbpaste`
  for your whole history (see below)
- No cloud, no accounts, no analytics, no telemetry, no network use except
  user-initiated update checks

## Install

Homebrew (macOS 14+):

    brew install --cask UnsaltedHash42/tap/pasteback
    xattr -dr com.apple.quarantine /Applications/Pasteback.app

The second line is required for now. The build is adhoc-signed (no Developer
ID, not notarized), and Homebrew 7 quarantines every cask download — macOS
then runs the app with restricted capabilities (clipboard reads and local
storage silently stop working). Stripping the attribute restores full
function. Re-run that line after each `brew upgrade`. Notarization is tracked
in [issue #1](https://github.com/UnsaltedHash42/PasteBack/issues/1); once it
ships, the plain `brew install` will be enough.

Direct download: get `Pasteback-1.0.0.zip` from
[Releases](https://github.com/UnsaltedHash42/PasteBack/releases), unzip
`Pasteback.app` to /Applications, and run the same `xattr -dr` line.

## Usage

**Open the panel.** Click the clipboard icon in the menu bar, or press
⌃⇧⌘C (works from any app). The panel shows your most recent items first.

**Restore an item.** Click it. Its content goes back on the system clipboard;
Pasteback never pastes into apps by itself, so press ⌘V in the target app.
Nothing is auto-pasted and no Accessibility permission is used.

**Search.** Type in the search field; the list filters by preview text as you
type.

**Pin, delete, clear.** Right-click an item for *Restore to Clipboard*,
*Pin*/*Unpin*, and *Delete*. Pinned items never expire and show a pin marker.
The trash button in the footer clears everything (asks first). The gear opens
Settings; the power button quits.

**What gets captured.** Plain text; rich text is kept as plain text; URLs
(saved as link + text, so they paste into both browsers and editors); PNG/TIFF
images up to 10 MB (with a thumbnail in the list); file references stored as
paths — the files themselves are never copied. Consecutive identical copies
are not stored twice.

**How long items live** (unpinned; all configurable in Settings):

| Kind | Default expiry |
|---|---|
| Text and links | 1 hour |
| Images | 1 day |
| File references | 1 day |
| Likely secrets | 30 seconds |
| Pinned items | never |

Likely secrets are detected heuristically: JWTs, prefixed API keys
(`sk-…`, `ghp_…`, `AKIA…`, `xoxb-…`, `AIza…`), `key = value` secrets, bearer
tokens, standalone token-shaped strings, and card numbers that pass the Luhn
check. Ordinary prose is not flagged. This is a best-effort nudge toward
safety, not a password manager.

**Global hotkey.** Default ⌃⇧⌘C, and fully customizable: Settings → Global
Hotkey → Record, then press the new combination (at least one modifier key;
Esc cancels). The enable toggle turns the hotkey off entirely. If a chosen
combination is unavailable, the previous hotkey keeps working and Settings
shows a warning until you pick another one.

**Launch at login.** Toggle it in Settings. Registered through SMAppService,
so it appears in System Settings → General → Login Items and can be revoked
there.

**Command line.** Pasteback also works from the shell. The Homebrew cask
installs the binary as `pasteback`; from a direct download it lives inside
the app bundle (`Pasteback.app/Contents/MacOS/pasteback-cli`). The CLI talks
to the running app over a local socket in the storage folder (`ipc.sock`,
readable only by your user) — it never touches the encrypted store or the
Keychain itself, so nothing is decrypted outside the app. The app must be
running.

    pasteback list [count] [--json]    newest first; index 0 is the most recent item
    pasteback get <index>              print one item's full content to stdout

Examples:

    $ pasteback list 5
    0   Text  25 seconds ago  Q3 revenue numbers…
    1   Link  1 hour ago      https://example.com/article
    2*  Text  yesterday       pinned snippet

    $ pasteback get 0
    Q3 revenue numbers, full clipboard text…

Text and links print exactly what was copied (pipe or redirect them like
`pbpaste`); file references print one path per line; images write raw
bytes, so redirect them (`pasteback get 2 > clip.png`). `*` marks pinned
items. `--json` prints machine-readable entries (`index`, `kind`,
`preview`, `createdAt`, `isPinned`). Exit code 1 with a message on stderr
if the app is not running or the index is out of range.

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

## Run from source

    make run            # dev build directly from the CLI
    open dist/Pasteback.app

## Tests

    make test

(On CLT installs this loads the Swift Testing macro plugin explicitly; see the
Makefile.) 63 tests cover pasteboard capture/classification/restore, storage
dedupe/limit/expiry, encryption (on-disk ciphertext, round-trip, wrong key,
Keychain), retention per kind + sensitive + pinned, sensitive detection,
hotkey registration/change/conflict handling (including failed swaps keeping
the previous hotkey), and the CLI socket protocol (list/get round-trips,
error paths, formatting).

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

To remove everything: quit Pasteback, delete the app, delete
`~/Library/Application Support/Pasteback`, and remove the two Keychain items
above. Clear All (in the panel or Settings) wipes just the history file.

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
Keychain, prints the public key — kept locally at
`Resources/SparklePublicED.key`, not committed), host the appcast somewhere
real, set that URL as `SUFeedURL` in `scripts/Resources/App-Info.plist`, and
sign each release with Sparkle's `sign_update`.

## Settings

Launch at login · global hotkey (recordable; conflicts reported) · maximum
stored items (10/20/50/100) · expiration for text / images / file references
· sensitive-item expiration · open storage folder · check for updates ·
clear all items.

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
- The documented install path (brew install → `xattr -dr` quarantine strip →
  launch) was verified the same way on the Homebrew-installed copy.
- The CLI was verified end-to-end against both the dist build and the
  Homebrew-installed 1.1.0 build: `pasteback list`, `list --json`, `get`,
  and the out-of-range error path.
- UI (panel click-through) was not driven programmatically (no accessibility
  permission in the build environment); restore behavior is covered by unit
  tests against real `NSPasteboard` instances.

## License

MIT — see [LICENSE](LICENSE).
