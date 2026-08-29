# Waydroid audio probe

This small dependency-free Android application plays a fixed 440 Hz tone as a
`STREAM_MUSIC`/`USAGE_MEDIA` `AudioTrack` for 20 seconds. It measures the real
Android-to-PipeWire playback path without depending on YouTube, Google
services or a network connection.

## Build

The requirements are the same as the Camera2 probe: a JDK with `javac`, `jar`
and `keytool`, `zip`, Android SDK platform 34, and build-tools 36.0.0.

```sh
ANDROID_SDK_ROOT="$HOME/Android/Sdk" ./build.sh
```

## Run and measure

With Waydroid running, install and launch it:

```sh
waydroid app install build/waydroid-audio-probe.apk
waydroid app launch dev.lolren.waydroidaudioprobe
```

During the 20-second tone, capture the host stream as the normal login user:

```sh
XDG_RUNTIME_DIR=/run/user/10000 pactl list sink-inputs
```

The expected Android log line is:

```text
WaydroidAudioProbe: AUDIO_START ... stream=MUSIC usage=MEDIA ... volume=1.0
```

The stream's PipeWire `application.name`, volume, mute state, target sink and
format are the evidence for diagnosing attenuation. Do not change the global
speaker volume to compensate until the Android stream itself has been checked.
