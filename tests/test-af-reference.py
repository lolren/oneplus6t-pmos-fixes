#!/usr/bin/env python3
"""Regression model for the continuous-AF reference hysteresis.

This mirrors only the reference/restart decision boundary in the simple IPA.
It deliberately does not pretend to replace a physical actuator test.
"""

from __future__ import annotations


def monitor(
    metrics: list[float],
    *,
    reference: float = 100.0,
    restart_ratio: float = 0.7,
    decay: float = 0.98,
    rise: float = 0.2,
    rise_windows: int = 3,
    window_ms: int = 250,
    hold_ms: int = 1500,
    restart_delay_ms: int = 3000,
) -> tuple[int, float]:
    candidate = 0.0
    rise_samples = 0
    low_since: int | None = None
    restarts = 0

    for window, metric in enumerate(metrics, start=1):
        now = window * window_ms
        previous = reference
        threshold = previous * restart_ratio

        if metric > previous:
            if not rise_samples:
                candidate = metric
            else:
                candidate = min(candidate, metric)
            rise_samples += 1
            if rise_samples >= rise_windows:
                reference = previous + (candidate - previous) * rise
                candidate = 0.0
                rise_samples = 0
        else:
            candidate = 0.0
            rise_samples = 0
            reference = max(metric, previous * decay)

        if now >= restart_delay_ms and metric < threshold:
            if low_since is None:
                low_since = now
            elif now - low_since >= hold_ms:
                restarts += 1
                low_since = None
                reference = 100.0
        else:
            low_since = None

    return restarts, reference


def main() -> None:
    stable = [100.0] * 12

    # A single contrast spike must not promote the baseline or trigger a scan
    # when the ordinary scene metric returns.
    restarts, reference = monitor(stable + [1000.0] + [100.0] * 20)
    assert restarts == 0, restarts
    assert reference == 100.0, reference

    # Three consecutive high windows may promote the baseline conservatively.
    restarts, reference = monitor(stable + [200.0] * 3 + [100.0])
    assert restarts == 0, restarts
    assert abs(reference - 117.6) < 1e-9, reference

    # A sustained loss remains actionable after the configured hold period.
    restarts, _ = monitor(stable + [60.0] * 8)
    assert restarts == 1, restarts

    # A low window that recovers before the hold period is not a refocus event.
    restarts, _ = monitor(stable + [60.0, 100.0] * 8)
    assert restarts == 0, restarts

    print("PASS: continuous-AF reference hysteresis")


if __name__ == "__main__":
    main()
