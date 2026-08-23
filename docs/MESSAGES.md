# Messages application

postmarketOS Phosh labels GNOME Chatty as **Chats**. It provides SMS/MMS through
ModemManager and `mmsd-tng`; the installed desktop application ID is
`sm.puri.Chatty`.

## Safe check and fallback launch

Run the read-only check as the graphical login user, not with `sudo`:

```sh
./scripts/check-messages
```

To request the same D-Bus activation used by the desktop entry and verify that
a GTK window object appears:

```sh
./scripts/check-messages --activate
```

The command checks packaged files, runtime-library resolution, the user daemon,
the D-Bus owner and the exported window object. It does not read Chatty's
history database, contacts, telephone numbers or message content. `--activate`
only asks Chatty to present its window.

## Result on the tested phone

The original report that Chats did not open was not reproducible after mobile
data and time synchronization were configured:

- Chatty `0.8.9-r13` and its desktop/D-Bus/systemd files were present;
- all runtime libraries resolved;
- `sm.puri.Chatty-daemon.service` remained active with no restart or coredump;
- direct GApplication activation created a stable window in about 0.22 seconds;
- the exact desktop-file path, `gtk-launch sm.puri.Chatty`, created one in about
  0.29 seconds; and
- accessibility exposed a visible/showing `Chats` window at 360 by 733 pixels.

The test deliberately closed only the window between launches. The background
daemon and all message data remained untouched. A screen-on physical tap still
needed confirmation because an SSH process cannot obtain the input serial used
for a genuine Wayland activation token. The user subsequently confirmed that
the application opens from the touchscreen, completing that check.

## Separate display evidence

Phoc recorded repeated DRM atomic-commit failures with `Resource busy`, and the
kernel logged DPU errors including `no encoder found for crtc 0`. Phosh also
timed out while starting the unrelated Software application. A window can
exist while a failed display commit makes it appear that nothing opened. This
is a plausible presentation-layer explanation, not proof of the original
symptom.

Do not work around this by deleting Chatty data, disabling its daemon, or
reinstalling packages. First reproduce with the screen awake. If
`check-messages --activate` reports a window but no window is drawn, collect
sanitized Phosh, Phoc and kernel DRM logs; that is a presentation/display issue,
not a Chatty startup failure.

## Upstream notes

[Chatty upstream issue 795](https://gitlab.gnome.org/World/Chatty/-/work_items/795)
documents historical multi-second opening latency, but this phone opened the
window in under 0.3 seconds. [Upstream merge request
1488](https://gitlab.gnome.org/World/Chatty/-/merge_requests/1488) fixes a
separate Phoc focus-detection bug after the `0.8.9` release. That change affects
notification/focus behavior; it should not be represented as a fix for a
window-creation failure.

The reported failure is resolved and cannot currently support an upstream bug
report. If it recurs, record a timestamp and use the diagnostic to distinguish
absent-window from mapped-but-not-presented behavior before filing one.
