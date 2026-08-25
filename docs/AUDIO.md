# OnePlus 6T audio routing

The OnePlus 6T's ALSA UCM profile exposes separate built-in nodes for the
speaker, earpiece, bottom microphone and top microphone. The postmarketOS
WirePlumber package also carries a PulseAudio-compatibility fragment that can
disable the ALSA hardware monitor. When that fragment wins, `pactl` may show a
stale compatibility card while `wpctl` has no real audio device.

## Fix included here

`config/wireplumber/90-oneplus6t-audio.conf` re-enables WirePlumber's ALSA and
Bluetooth hardware monitors after the distro fragment. It is a late, additive
configuration file, so it does not replace WirePlumber's system configuration.

`scripts/audio-route-policy` polls the PulseAudio compatibility API exposed by
PipeWire and changes only the default source when the selected output is a
built-in OnePlus node:

| Output | Default microphone |
| --- | --- |
| Built-in speaker | Top microphone (`Mic2`) |
| Earpiece / voice-call sink | Bottom microphone (`Mic1`) |
| Connected headphones | Headset microphone when present, otherwise bottom microphone |

USB and Bluetooth defaults are left alone. The policy does not rewrite ALSA
mixer controls and does not change the modem, q6voice service or boot files.

The policy supports `--once` for bounded validation. The repository test suite
uses a fake PulseAudio-compatibility endpoint to verify the speaker-to-top-mic,
earpiece-to-bottom-mic and headphones-to-headset-mic mappings without touching
the host audio session. The installed user service runs the normal continuous
two-second reconciliation loop.

## Install and enable

From this repository:

```sh
make test
sudo make install PREFIX=/usr/local
systemctl --user daemon-reload
systemctl --user enable --now oneplus6t-audio-route.service
pmos-check-audio-routing
```

For a package build, `make install DESTDIR=... PREFIX=/usr` installs the
WirePlumber fragment and user unit under their normal package paths. Package
activation is intentionally separate: enable the user unit only after
checking the installed files.

Restarting WirePlumber is enough to apply the monitor override:

```sh
systemctl --user restart wireplumber.service
```

No reboot is required. If audio nodes disappear after a distro update, run
`pmos-check-audio-routing` first and confirm that WirePlumber is active. The
project does not remove `/var/lib/alsa/asound.state`; current pMOS images should
keep `alsa-restore` disabled on this device.

## Current call-audio boundary

The phone's installed `callaudiod` 0.1.99 daemon reports no usable output when
it starts while PipeWire exposes the unavailable headphone sink first. This is
why a speakerphone toggle can still fail even after the underlying audio card
is visible. The default-source policy above is safe and works for the nodes
that the active call application selects; it does not claim to add a missing
q6voice speakerphone route. The next upstreamable audio change is a UCM/
call-audio integration test with an actual modem call, not a blind mixer edit.

## Reproduction evidence

On a working installation, `wpctl status` must show `Built-in Audio` with a
speaker sink and at least bottom/top microphone sources. `pactl list cards` must
show `HiFi` and `Voice Call` profiles. In HiFi, selecting the built-in speaker
must select `HiFi__Mic2__source`; in Voice Call, selecting the earpiece must
select `Voice_Call__Mic__source`.
