/* SPDX-License-Identifier: GPL-3.0-or-later */
package dev.lolren.waydroidaudioprobe;

import android.app.Activity;
import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.os.Bundle;
import android.os.Process;
import android.util.Log;
import android.widget.TextView;

/** Plays a fixed STREAM_MUSIC tone so the Waydroid host bridge can be measured. */
public final class AudioProbeActivity extends Activity {
    private static final String TAG = "WaydroidAudioProbe";
    private static final int SAMPLE_RATE = 48000;
    private static final int CHANNELS = AudioFormat.CHANNEL_OUT_STEREO;
    private static final int DURATION_SECONDS = 20;

    private AudioTrack track;
    private Thread playbackThread;
    private volatile boolean playing;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        TextView view = new TextView(this);
        view.setText("Waydroid audio probe: playing a 440 Hz STREAM_MUSIC tone");
        view.setTextSize(18.0f);
        view.setPadding(32, 32, 32, 32);
        setContentView(view);
        startPlayback();
    }

    private void startPlayback() {
        final int minimum = AudioTrack.getMinBufferSize(
                SAMPLE_RATE, CHANNELS, AudioFormat.ENCODING_PCM_16BIT);
        if (minimum <= 0) {
            Log.e(TAG, "AUDIO_ERROR getMinBufferSize=" + minimum);
            finish();
            return;
        }

        final AudioAttributes attributes = new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build();
        final AudioFormat format = new AudioFormat.Builder()
                .setSampleRate(SAMPLE_RATE)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setChannelMask(CHANNELS)
                .build();
        track = new AudioTrack(attributes, format, Math.max(minimum, 8192),
                AudioTrack.MODE_STREAM, AudioManager.AUDIO_SESSION_ID_GENERATE);
        if (track.getState() != AudioTrack.STATE_INITIALIZED) {
            Log.e(TAG, "AUDIO_ERROR AudioTrack state=" + track.getState());
            track.release();
            track = null;
            finish();
            return;
        }

        track.setVolume(1.0f);
        Log.i(TAG, "AUDIO_START uid=" + Process.myUid()
                + " stream=MUSIC usage=MEDIA sampleRate=" + SAMPLE_RATE
                + " volume=1.0"
                + " frames=" + (SAMPLE_RATE * DURATION_SECONDS));
        playing = true;
        playbackThread = new Thread(() -> {
            final short[] samples = new short[2048 * 2];
            final double increment = 2.0 * Math.PI * 440.0 / SAMPLE_RATE;
            double phase = 0.0;
            final long end = System.nanoTime()
                    + DURATION_SECONDS * 1_000_000_000L;
            track.play();
            while (playing && System.nanoTime() < end) {
                for (int i = 0; i < samples.length; i += 2) {
                    short sample = (short) (Math.sin(phase) * 16384.0);
                    samples[i] = sample;
                    samples[i + 1] = sample;
                    phase += increment;
                    if (phase >= 2.0 * Math.PI) {
                        phase -= 2.0 * Math.PI;
                    }
                }
                int written = track.write(samples, 0, samples.length,
                        AudioTrack.WRITE_BLOCKING);
                if (written < 0) {
                    Log.e(TAG, "AUDIO_ERROR write=" + written);
                    break;
                }
            }
            Log.i(TAG, "AUDIO_DONE");
            runOnUiThread(this::finish);
        }, "audio-probe");
        playbackThread.start();
    }

    @Override
    protected void onDestroy() {
        playing = false;
        if (track != null) {
            track.pause();
            track.flush();
            track.release();
            track = null;
        }
        super.onDestroy();
    }
}
