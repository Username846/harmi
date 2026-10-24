#!/usr/bin/env python3
"""Renders the title-screen diss track: "Long Boy Diss (Black Side Freestyle)".

A five-minute boom-bap beat synthesized with numpy, with every lyric rapped
once by a speech synthesizer (no line repeats) and squeezed into its bar.
Writes:
  assets/audio/diss_track.ogg      the song (mono Ogg Vorbis)
  scripts/title/diss_lyrics.gd     each line's start/end time for the scrolling ticker

Needs numpy, the `flite` speech synthesizer (voice "rms") and ffmpeg with
libvorbis. Run from the repository root:  python3 tools/gen_diss.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 22050
BPM = 90
BAR = 4 * 60.0 / BPM  # 2.667 s
BARS = 112
ROOT = os.path.join(os.path.dirname(__file__), "..")
rng = np.random.default_rng(1993)

# (bar, line). Each line is rapped exactly once.
INTRO = [(2, "Yo. This one goes out to the whole Black side of the board.")]
VERSE1 = [
    "Ashen Gambit on the mic and I'm taller than the block",
    "Seven feet of ivory, I'm a walking grandfather clock",
    "You bust shit while I bust nuts.",
    "You sweep the squares while I'm counting up my bucks",
    "Rolled up to the corner store in a lowrider coupe",
    "Bought a sniper and a gourd, now I'm hunting down your troop",
    "Your knight move crooked, yeah, it only goes in Ls",
    "Mine hop over buildings while your horse just smells",
    "Your queen got the power but she never got the sauce",
    "Took her on a dinner date, now she calling me the boss",
    "I do odd jobs, really odd jobs, money in the drawer",
    "Posed as a garden gnome and still I'm making more",
    "Your bishop moving sideways like he dodging the rent",
    "Diagonal hustle, every penny that he spent",
    "Hey we got Oscar Mayer over here",
    "Little wiener pawn, two squares and he disappear",
    "Your rook stuck in the corner like he grounded by his mom",
    "Castling every Tuesday, call that dude a sitcom",
    "Pink slip race, I left your hatchback in the smoke",
    "Now your piece can't move, he a pedestrian joke",
    "Shifted in the green band with the nitrous in the tank",
    "Drove your car to Gambit Goods and parked it at the bank",
    "Every time you capture you be crying in a maze",
    "Punching on a footlocker for seven straight days",
    "I walk the labyrinth like I'm holding the deed",
    "Inspect, open, punch and use, that's all I need",
    "Your mood so gloomy that it's raining on your head",
    "Little storm cloud following you all the way to bed",
    "Took your pawn to a picnic, now he loves me more",
    "Told him he could promote if he knocks on my door",
    "We bout to hood style on these mofos",
    "Pull up with the neighbors in the lowrider, slow mo",
]
VERSE2 = [
    "Nah I ain't about chess what the fuck is a bishop",
    "Looking like a salt shaker, get up out my kitchen, stop",
    "Pulled the Beyblade rip cord till the bassline hit the floor",
    "Snapped it off the launcher, now your king can't find the door",
    "Knocked your knight flat on his back, he seeing little stars",
    "Lose a turn, sit and learn, while I'm racing fancy cars",
    "Yugi in the graveyard talking heart of the cards",
    "I pulled a Drive-By booster, now he calling for his guards",
    "Brought my dead rook back with a dragon and a sniper",
    "Children's card game, but I play it like a viper",
    "Your king so anxious that he never leaves his square",
    "Always in check, man, he losing all his hair",
    "My king got a driver and a custom leather seat",
    "Your king got a curfew and a babysitter, sweet",
    "Double shot espresso, so I move two times, cuz",
    "By the time you blink I already did what I does",
    "You talk about the center, I'm the center of attention",
    "Fifty move rule, I'm a fifty bar extension",
    "En passant your cousin, he was sneaking by the side",
    "Caught him with a pawn and then I took him for a ride",
    "Your scrolls in the scriptorium are dusty and dead",
    "Lit a candle in the dark and read your diary instead",
    "Bell tower ringing, that's the sound of you losing",
    "Three bells, four bells, I don't care what you're choosing",
    "Ward Charm on my neck and a whetstone on my blade",
    "Twenty five more hit points, I don't ever get afraid",
    "You sip Mana Tincture like it's pink lemonade",
    "I drink Health Draught straight, I'm a walking barricade",
    "Took your bishop out to sea on a sunset cruise",
    "Scattering the ashes, man, he had nothing to lose",
    "Your skinny neck look like a giraffe in a hoodie",
    "Mine look like a skyscraper serving up the goodies",
]
BREAK = [(73, "Hold up. Let the beat breathe. Okay. Back to violating.")]
VERSE3 = [
    "Got a pet rock named Gerald and he harder than your squad",
    "He don't fight, he don't race, but he still look like a god",
    "Decorative gourd on my dashboard for luck",
    "Commemorative spoon, I stirred up all your stuff",
    "You need a headlamp just to find your own way home",
    "Dark mood, dark maze, you crying on the phone",
    "Called the Drive-By Hotline, said bring the whole crew",
    "Neighbor board pulled up and your back rank is through",
    "Sniper on the e-file and the line is clear",
    "One shot, no labyrinth, your pawn is out of here",
    "Ash in my satchel and I throw it in your eyes",
    "Blinded in the duel, now you swinging at the skies",
    "Your rook got a van with a busted transmission",
    "Lost it in a race, now he walking on a mission",
    "Used car lot, I bought the keys for twenty bucks",
    "My pawns ride in style while yours hitch rides on trucks",
    "Black side bluffing, all that marble, no muscle",
    "White side shining, every square is a hustle",
    "Checkmate coming and you know it's not a bluff",
    "Final duel with your king and he's eating my dust",
    "He crumbles into ash and I sweep him in a dustpan",
    "Mail him back to Yugi with a note that says nice plan",
    "I'm the long boy of the board, I'm the ivory tower",
    "Every move I make got that elongated power",
    "You a short little checker on the wrong kind of table",
    "I'm a legend in the labyrinth, a myth and a fable",
    "Machine on the Black side thinking twelve hundred moves",
    "Still can't calculate the way your boy grooves",
    "Easy, Normal, Hard, man, I'm deadly on all three",
    "Even two player mode I'm still beating me",
    "So bow to the tall boy, put your crown on the floor",
    "Pawn to e-four and I'm kicking in your door",
]
OUTRO = [(108, "That's the track. Black side, you're done. The board is mine."),
         (110, "Elongated pieces. Ashen Gambit. Mic drop. Peace.")]

SPOKEN = {"Ls": "L's", "e-file": "e file", "e-four": "e four", "mofos": "mo fos", "Yugi": "Yoogee",
          "Beyblade": "bay blade", "En passant": "On pa sont"}

CHORDS = [[48, 51, 55], [44, 48, 51], [41, 44, 48], [43, 47, 50]]  # Cm Ab Fm G (midi)


def schedule():
    lines = list(INTRO)
    lines += [(4 + i, l) for i, l in enumerate(VERSE1)]
    lines += [(40 + i, l) for i, l in enumerate(VERSE2)]
    lines += list(BREAK)
    lines += [(76 + i, l) for i, l in enumerate(VERSE3)]
    lines += list(OUTRO)
    texts = [l for _, l in lines]
    assert len(texts) == len(set(texts)), "a lyric repeats"
    assert len(VERSE1) == len(VERSE2) == len(VERSE3) == 32
    return lines


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def kick():
    t = t_axis(0.35)
    f = 48 + 110 * np.exp(-t * 28)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * 0.95


def snare():
    t = t_axis(0.25)
    n = rng.standard_normal(len(t))
    n = np.convolve(n, [1, -0.6], "same")
    return (n * np.exp(-t * 18) * 0.45 + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25) * 0.35)


def hat(open_=False):
    t = t_axis(0.25 if open_ else 0.05)
    n = np.convolve(rng.standard_normal(len(t)), [1, -2, 1], "same") * 0.22
    return n * np.exp(-t * (14 if open_ else 80))


def bass(m, dur):
    t = t_axis(dur)
    f = hz(m - 12) * (1 + 0.06 * np.exp(-t * 20))
    s = np.sin(2 * np.pi * np.cumsum(f) / SR)
    s = np.tanh(s * 1.8)
    return s * np.minimum(t / 0.01, 1) * np.exp(-t * 1.4) * 0.5


def keys(notes, dur):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for m in notes:
        f = hz(m + 12)
        out += np.sin(2 * np.pi * f * t) * np.exp(-t * 3.0) + 0.3 * np.sin(4 * np.pi * f * t) * np.exp(-t * 6)
    return out * 0.09


def place(buf, s, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    end = min(len(buf), i + len(s))
    buf[i:end] += s[: end - i]


def beat(total):
    buf = np.zeros(int(total * SR))
    step = BAR / 16
    for bar in range(BARS):
        t0 = bar * BAR
        section = "intro" if bar < 4 else "break" if 72 <= bar < 76 or 36 <= bar < 40 else "outro" if bar >= 108 else "verse"
        chord = CHORDS[bar % 4]
        # keys: two stabs per bar, swung
        place(buf, keys(chord, BAR * 0.45), t0)
        place(buf, keys(chord, BAR * 0.4), t0 + step * 6)
        if section == "intro" and bar < 2:
            continue
        # 808 bass on the root
        place(buf, bass(chord[0], BAR * 0.6), t0)
        place(buf, bass(chord[0] + (7 if bar % 2 else 0), BAR * 0.3), t0 + step * 10)
        if section in ("break",):
            # stripped down: hats and a lonely snare
            for k in range(0, 16, 2):
                place(buf, hat(), t0 + k * step + (0.02 if k % 4 == 2 else 0))
            place(buf, snare() * 0.6, t0 + step * 12)
            continue
        for k in (0, 7, 10):
            place(buf, kick(), t0 + k * step)
        if bar % 4 == 3:
            place(buf, kick() * 0.7, t0 + 14 * step)
        for k in (4, 12):
            place(buf, snare(), t0 + k * step)
        for k in range(16):
            if k % 2 == 0 or (bar >= 76 and k % 4 == 3):
                place(buf, hat(open_=(k == 14 and bar % 2 == 1)), t0 + k * step + (0.025 if k % 4 == 2 else 0))
    # vinyl crackle
    n = len(buf)
    crackle = np.zeros(n)
    idx = rng.integers(0, n, int(total * 30))
    crackle[idx] = rng.uniform(-0.15, 0.15, len(idx))
    buf += crackle
    return buf


def read_wav(path):
    with wave.open(path) as w:
        sr = w.getframerate()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float) / 32768.0
    if sr != SR:
        x = np.arange(int(len(data) * SR / sr)) * sr / SR
        data = np.interp(x, np.arange(len(data)), data)
    return data


def rap(text, slot, tmp):
    spoken = text
    for k, v in SPOKEN.items():
        spoken = spoken.replace(k, v)
    raw = os.path.join(tmp, "raw.wav")
    out = os.path.join(tmp, "out.wav")
    subprocess.run(["flite", "-voice", "rms", "-t", spoken, "-o", raw], check=True)
    with wave.open(raw) as w:
        dur = w.getnframes() / w.getframerate()
    # drop the pitch a little for attitude, then fit the line into its bar
    pitched = dur / 0.9
    tempo = min(2.0, max(0.9, pitched / slot))
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", raw, "-af",
                    "asetrate=14400,aresample=%d,atempo=%.4f,highpass=f=90" % (SR, tempo), out], check=True)
    v = read_wav(out)
    v = v / max(1e-6, np.max(np.abs(v)))
    return np.tanh(v * 2.2) * 0.6


def main():
    lines = schedule()
    total = BARS * BAR + 1.5
    mix = beat(total) * 0.55
    vox = np.zeros_like(mix)
    timings = []
    with tempfile.TemporaryDirectory() as tmp:
        for bar, text in lines:
            start = bar * BAR + 0.03
            slot = BAR * (1.85 if bar in (2, 73, 108, 110) else 0.93)
            v = rap(text, slot, tmp)
            place(vox, v, start)
            # a quiet double a hair later thickens the voice
            place(vox, v * 0.25, start + 0.022)
            timings.append((start, start + len(v) / SR, text))
            print("%6.2f  %s" % (start, text))
    mix += vox
    mix *= np.clip((total - np.arange(len(mix)) / SR) / 1.5, 0, 1)
    mix = np.tanh(mix * 1.1)
    mix = mix / np.max(np.abs(mix)) * 0.92
    os.makedirs(os.path.join(ROOT, "assets", "audio"), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "mix.wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((mix * 32767).astype("<i2").tobytes())
        ogg = os.path.join(ROOT, "assets", "audio", "diss_track.ogg")
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "2", ogg], check=True)
    gd = ['## Generated by tools/gen_diss.py: when each line of the title-screen diss track is rapped.',
          'extends RefCounted', '', 'const TITLE := "Long Boy Diss (Black Side Freestyle)"',
          'const LENGTH := %.2f' % total, '', 'const LINES := [']
    for s, e, text in timings:
        gd.append('\t[%.2f, %.2f, "%s"],' % (s, e, text.replace('"', '\\"')))
    gd.append(']')
    with open(os.path.join(ROOT, "scripts", "title", "diss_lyrics.gd"), "w") as f:
        f.write("\n".join(gd) + "\n")
    print("wrote diss_track.ogg (%.1f s, %d lines)" % (total, len(timings)))


if __name__ == "__main__":
    main()
