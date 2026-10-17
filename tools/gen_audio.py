#!/usr/bin/env python3
"""Renders the game's audio into assets/audio/ (needs numpy).

  beyblade_stairs.wav  the looping bassline: a battle top launched down an oak
                       staircase - wooden thocks on every step, a descending
                       bass, metal pings and the whir of the spin
  ripcord.wav          the rip cord being pulled
  crash.wav            the Beyblade snapping off and crashing into the board

Run from the repository root:  python3 tools/gen_audio.py
"""
import os
import wave

import numpy as np

SR = 22050
BPM = 150
BEAT = 60.0 / BPM
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


def note_hz(name):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + names[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def bass(freq, dur):
    """Plucky saw bass with a closing 'filter' and a sub octave."""
    t = t_axis(dur + 0.08)
    out = np.zeros_like(t)
    for n in range(1, 10):
        out += np.sin(2 * np.pi * freq * n * t) / n * np.exp(-n * 7.0 * t)
    out += 0.7 * np.sin(2 * np.pi * freq * 0.5 * t)
    env = np.minimum(t / 0.004, 1.0) * (0.55 + 0.45 * np.exp(-t * 9.0))
    env *= np.clip((dur + 0.08 - t) / 0.08, 0.0, 1.0)
    return out * env * 0.42


def thock(pitch=210.0, strength=1.0):
    """An oak step taking a hit: resonant wood body plus a sharp click."""
    t = t_axis(0.22)
    sweep = pitch * (1.0 + 0.35 * np.exp(-t * 60.0))
    body = np.sin(2 * np.pi * np.cumsum(sweep) / SR) * np.exp(-t * 38.0)
    low = np.sin(2 * np.pi * 92.0 * t) * np.exp(-t * 22.0) * 0.8
    click = rng.standard_normal(len(t)) * np.exp(-t * 450.0)
    click = np.convolve(click, [1, -1], "same") * 0.5
    return (body * 0.9 + low + click) * 0.55 * strength


def ping(strength=1.0):
    """The metal attack ring glancing off a step."""
    t = t_axis(0.3)
    out = np.zeros_like(t)
    for f, a, d in ((2380, 1.0, 16), (3710, 0.6, 22), (5120, 0.35, 30), (1630, 0.4, 12)):
        out += a * np.sin(2 * np.pi * f * t) * np.exp(-t * d)
    return out * 0.16 * strength


def kick():
    t = t_axis(0.2)
    f = 45 + 95 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14) * 0.75


def hiss(dur=0.05, strength=1.0):
    t = t_axis(dur)
    n = rng.standard_normal(len(t))
    n = np.convolve(n, [1, -2, 1], "same") * 0.25
    return n * np.exp(-t * 70) * 0.18 * strength


def place(buf, sound, at_sec):
    i = int(at_sec * SR)
    end = i + len(sound)
    if end <= len(buf):
        buf[i:end] += sound
    else:
        # wrap the tail around so the loop is seamless
        k = len(buf) - i
        buf[i:] += sound[:k]
        buf[: len(sound) - k] += sound[k:]


def render_loop():
    bars = 8
    length = bars * 4 * BEAT
    buf = np.zeros(int(round(length * SR)))
    e = 0.5  # eighth note in beats

    def at(bar, beat):
        return (bar * 4 + beat) * BEAT

    # bars 1-2: launched down the stairs, one step per beat
    steps = ["E3", "D3", "C3", "B2", "A2", "G2", "F#2", "E2"]
    for i, n in enumerate(steps):
        bar, beat = divmod(i, 4)
        place(buf, bass(note_hz(n), BEAT * 0.9), at(bar, beat))
        place(buf, thock(240 - i * 9), at(bar, beat))
        if i % 2 == 1:
            place(buf, ping(0.8), at(bar, beat + 0.5))
    # bars 3-4: bouncing round the landing
    riff = [("E2", 0), ("E2", 1), ("E3", 1.5), ("E2", 2.5), ("G2", 3), ("A2", 3.5),
            ("B2", 4), ("B2", 5), ("D3", 5.5), ("B2", 6.5), ("A2", 7), ("G2", 7.5)]
    for n, b in riff:
        place(buf, bass(note_hz(n), BEAT * e * 0.95), at(2, b))
    for b in (0, 1.5, 2.5, 4, 5.5, 6.5):
        place(buf, thock(200, 0.8), at(2, b))
    for b in (1, 3, 5, 7):
        place(buf, ping(0.6), at(2, b + 0.25))
    # bars 5-6: down the next flight, two steps per beat
    run = ["E3", "D3", "C3", "B2", "A2", "G2", "F#2", "E2", "D3", "C3", "B2", "A2", "G2", "F#2", "E2", "D2"]
    for i, n in enumerate(run):
        b = i * e
        place(buf, bass(note_hz(n), BEAT * e * 0.92), at(4, b))
        place(buf, thock(250 - (i % 8) * 12, 0.85), at(4, b))
        if i % 4 == 3:
            place(buf, ping(1.0), at(4, b + 0.25))
    # bars 7-8: tumbling to the bottom, then a skittering climb back to the top
    tumble = [("E2", 0), ("E3", 0.75), ("E2", 1.5), ("G2", 2), ("E2", 3), ("B2", 3.5),
              ("E2", 4), ("E3", 4.75), ("D3", 5.5), ("C3", 6)]
    for n, b in tumble:
        place(buf, bass(note_hz(n), BEAT * 0.45), at(6, b))
        place(buf, thock(190, 0.9), at(6, b))
    climb = ["E2", "F#2", "G2", "A2", "B2", "C3", "D3", "D#3"]
    for i, n in enumerate(climb):
        b = 6.5 + i * 0.1875
        place(buf, bass(note_hz(n), BEAT * 0.18), at(6, b))
        place(buf, thock(260 + i * 15, 0.5), at(6, b))
        place(buf, ping(0.35), at(6, b))
    # drums
    for bar in range(bars):
        for beat in (0, 2):
            place(buf, kick(), at(bar, beat))
        for k in range(8):
            place(buf, hiss(0.05, 1.0 if k % 2 else 0.6), at(bar, k * 0.5 + 0.25 * (k % 2 == 1)))
    # the whir of the top itself: two partials chopped by the blades passing
    t = np.arange(len(buf)) / SR
    drift = 1.0 + 0.025 * np.sin(2 * np.pi * t / length * 2)
    phase = 2 * np.pi * np.cumsum(1250.0 * drift) / SR
    whir = (np.sin(phase) + 0.45 * np.sin(2 * phase + 0.3)) * (0.55 + 0.45 * np.sin(2 * np.pi * 24.0 * t))
    buf += whir * 0.035
    return buf


def render_rip():
    t = t_axis(0.9)
    # the toothed cord: noise chopped by a sawtooth that speeds up
    rate = 25 + 140 * np.clip(t / 0.6, 0, 1)
    teeth = (np.mod(np.cumsum(rate) / SR, 1.0) < 0.35).astype(float)
    noise = rng.standard_normal(len(t))
    noise = np.convolve(noise, [1, 0, -1], "same") * 0.4
    zip_ = noise * teeth * np.clip(1 - (t - 0.55) / 0.15, 0, 1) * 0.6
    # the top spinning up
    f = 300 + 1500 * (1 - np.exp(-t * 4))
    whine = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.clip(t / 0.3, 0, 1) * np.clip((0.9 - t) / 0.3, 0, 1) * 0.25
    out = zip_ + whine
    place_buf = np.zeros(len(t) + int(0.3 * SR))
    place_buf[: len(out)] += out
    place_buf[int(0.62 * SR): int(0.62 * SR) + int(0.22 * SR)] += thock(300, 0.7)[: int(0.22 * SR)]
    return place_buf


def render_crash():
    t = t_axis(2.2)
    buf = np.zeros(len(t))
    # the impact
    noise = rng.standard_normal(int(0.5 * SR))
    tn = np.arange(len(noise)) / SR
    buf[: len(noise)] += noise * np.exp(-tn * 9) * 0.5
    buf[: int(0.2 * SR)] += kick()[: int(0.2 * SR)] * 1.2
    # pieces clattering over, quicker and quieter
    when = 0.08
    for i in range(14):
        s = thock(160 + rng.uniform(-30, 90), 0.9 * (1 - i / 16))
        i0 = int(when * SR)
        buf[i0: i0 + len(s)] += s[: len(buf) - i0]
        if i % 3 == 0:
            p = ping(0.9)
            buf[i0: i0 + len(p)] += p[: len(buf) - i0]
        when += 0.05 + 0.1 * rng.random()
    # the top wobbling to a stop
    f = 1300 * np.exp(-t * 1.2) + 120
    amp = np.clip(1 - t / 2.2, 0, 1) * (0.5 + 0.5 * np.sin(2 * np.pi * (14 * np.exp(-t)) * t))
    buf += np.sin(2 * np.pi * np.cumsum(f) / SR) * amp * 0.12
    return buf


def save(name, buf, peak=0.89):
    buf = np.tanh(buf * 1.1)
    buf = buf / max(1e-9, np.max(np.abs(buf))) * peak
    data = (buf * 32767).astype("<i2").tobytes()
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print("wrote", os.path.normpath(path), "%.2f s" % (len(buf) / SR))


if __name__ == "__main__":
    save("beyblade_stairs.wav", render_loop())
    save("ripcord.wav", render_rip(), 0.8)
    save("crash.wav", render_crash(), 0.95)
