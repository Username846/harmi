#!/usr/bin/env python3
"""Renders the title-screen album: three five-minute songs, each with its own
synthesized vocalist and beat, and no lyric ever repeated within a song.

  diss    "Long Boy Diss (Black Side Freestyle)"  MC Long Boy      boom-bap, 90 BPM
  epic    "Coronation of the Long Boys"           Sir Ivory        orchestral, 80 BPM, brass in the second half
  bounce  "Back Rank Bounce"                      Queen Cushy      dembow bounce, 100 BPM

Writes assets/audio/songs/<id>.ogg and scripts/title/lyrics_<id>.gd (each
line's start/end time, for the lyrics shown on the title screen).

Needs numpy, the `flite` speech synthesizer and ffmpeg with libvorbis.
Run from the repository root:  python3 tools/gen_songs.py [song ids...]
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..")
rng = np.random.default_rng(1993)

SPOKEN = {"Ls": "L's", "e-file": "e file", "e-four": "e four", "h-file": "h file", "a-file": "a file",
          "mofos": "mo fos", "Yugi": "Yoogee", "Beyblade": "bay blade", "En passant": "On pa sont",
          "h-five": "h five", "L-step": "L step", "L-shaped": "L shaped", "sixty-four": "sixty four"}


# --- lyrics -----------------------------------------------------------------------

DISS = {
    "intro": [(2, "Yo. This one goes out to the whole Black side of the board.")],
    "verses": [(4, [
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
    ]), (40, [
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
    ]), (76, [
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
    ])],
    "spoken": [(73, "Hold up. Let the beat breathe. Okay. Back to violating."),
               (108, "That's the track. Black side, you're done. The board is mine."),
               (110, "Elongated pieces. Ashen Gambit. Mic drop. Peace.")],
}

EPIC = {
    "intro": [(2, "Hear me, pieces of the board. The long boys march at dawn.")],
    "verses": [(4, [
        "Hear the horns of morning, every pawn is standing tall",
        "Seven feet of marble marching up to storm the wall",
        "From the a-file to the h-file, banners in the breeze",
        "Every rook a fortress and the bishops on their knees",
        "We were carved from ivory and polished in the flame",
        "Every crown in history is going to learn our name",
        "Violate my class and I'll dilate your ass",
        "Raise the drawbridge, pour the oil, nobody gets to pass",
        "Knights upon the hillside with their L-shaped charge",
        "Every square we conquer makes the kingdom twice as large",
        "Queen upon the throne with a scepter made of thunder",
        "Black side in the valley, watch them crumble, watch them wonder",
        "Light the beacons, ring the bells across the frozen keep",
        "Black king in his bedchamber can't get a wink of sleep",
        "We don't fear the labyrinth, we wander through the dark",
        "Punch the heart of every piece and leave a glowing mark",
        "Ash upon the battlefield like snow upon the stone",
        "Every fallen enemy, a stepping stone to the throne",
        "Hear the war drums thunder in the hall of sixty-four",
        "Sixty-four squares of glory and we're hungry for more",
        "Banners stitched with gold and a gambit in our blood",
        "We will ride the lowriders through the fire and the flood",
        "Oh, the Beyblade spinning like a comet in the sky",
        "Pull the cord of destiny and let the legends fly",
        "Every pawn a hero dreaming of the final rank",
        "Promotion is the prophecy, the queen is who we thank",
        "So kneel before the long boys, the tallest of them all",
        "We will stand forever while the shorter pieces fall",
    ]), (36, [
        "I ain't gay cuz but I'll take you on a date",
        "Candlelight and chivalry, I'll meet you at the gate",
        "Took the Black queen dancing at the castle by the sea",
        "Now she wears a white crown and she's fighting next to me",
        "Yugi in the graveyard shuffling his cards",
        "We will march straight through him with a hundred royal guards",
        "Children's games are over when the cavalry arrives",
        "Bring me back my fallen, give me back my soldiers' lives",
        "Odd jobs in the village, really odd jobs in the night",
        "Gold for every armor, every sword is shining bright",
        "Sniper on the tower and a drive-by in the moat",
        "Neighbor kingdom riding with hydraulics on a boat",
        "En passant, the arrow flies, a shadow at the side",
        "Never trust a pawn that only walks with half a stride",
        "Hark, the trumpets calling from the top of every tower",
        "The second half has come and this is our hour of power",
        "Fifty moves of silence and the cannons start to roar",
        "Threefold repetition is a coward's way of war",
        "Mood of every soldier like the sunrise on the plain",
        "Gloomy pieces fight like they've been standing in the rain",
        "So we dated every warrior and gave them all a rose",
        "Now they're marching elated with the sunset on their toes",
        "Brass across the battlefield, the sky is turning gold",
        "Every Black piece shivering, the marble running cold",
        "Bishops on the diagonal like lightning in a storm",
        "Rooks along the ranks and files, the castle keeps us warm",
        "Knights above the rooftops leaping over every wall",
        "Kings that fear the open board are destined for the fall",
    ]), (68, [
        "Now the final battle and the horizon burning red",
        "Every crown that crossed us is a candle for the dead",
        "Hear the brass of victory, the thunder of the drums",
        "Black side in the trenches, here the white tide comes",
        "Checkmate is a whisper that we carry on our blades",
        "Echo through the labyrinth and down the palisades",
        "Final duel, the king of night is trembling on his knees",
        "Health and mana draining like the leaves upon the trees",
        "Crumble into ashes, let the wind take you away",
        "We will sweep the board and we will rise another day",
        "Statues in the courtyard carved in honor of the tall",
        "Ivory and elongated, champions of all",
        "Children in the future will sing about this war",
        "Sixty-four squares of legend and a gambit at the core",
        "Pour the wine of triumph from the goblets of the brave",
        "Every gourd and spoon and rock is resting in the nave",
        "Gerald the pet rock is standing guard upon the hill",
        "He never moved a single square and he is standing still",
        "Raise your Beyblades high and let them spin into the sun",
        "Let the rip cords sing the song of battles that we won",
        "Every pawn a knight now, every knight a legend's name",
        "Every square of marble is a monument of flame",
        "And if you ever doubt us, hear the trumpets in the hall",
        "The long boys reign forever and the long boys never fall",
        "So remember us, the tallest pieces history has known",
        "Seven feet of glory, carved from ivory and bone",
        "When the brass is silent and the final candle dies",
        "Look up to the long boys, we are standing in the skies",
    ])],
    "spoken": [(33, "Rest your swords, my brothers. The war is far from over."),
               (65, "Hold the line. One more charge. For the board."),
               (96, "Glory to the board."),
               (98, "The long boys reign forever. Amen.")],
}

BOUNCE = {
    "intro": [(2, "Hey. It's your queen. Turn me up.")],
    "verses": [(4, [
        "Hey boys, hey board, the queen just walked in",
        "Glitter on my crown and a smirk upon my chin",
        "My tushy is so cushy won't you please give me the pushy",
        "Wiggle on the diagonal, the bishops getting pushy",
        "Make my pieces do the work, I'll be in the back and twerk",
        "Every pawn a gentleman, every knight a little jerk",
        "I move in any direction, baby, ask me how",
        "Straight lines, diagonals, I'm moving on you now",
        "Castle with the king? Nah, he's boring in the corner",
        "I'm out here every night, I'm the hottest on the border",
        "Rooks on the seventh rank looking at my dress",
        "Tell them keep it moving, honey, I don't do the chess",
        "Lipstick on the h-file, perfume on the e",
        "Every square I visit is a party just for me",
        "Knight came hopping over like a puppy with a bone",
        "Told him hop it backwards, leave the queen alone",
        "Date night at the alley and I bowled a perfect strike",
        "He bought me a Used Car and a little purple bike",
        "Pink slip racing in my high heel shoes",
        "Hit the nitrous, baby, now you're paying me your dues",
        "Shake it on the checkerboard, light and dark and light",
        "Black and white together till the morning, sleep tight",
        "Roses in my satchel and a gourd upon my hip",
        "Sipping Mana Tincture with a cherry on my lip",
        "Mood is elated, never gloomy in the rain",
        "Every time I'm captured they go crazy in the brain",
        "My labyrinth is lit up like a disco ball",
        "Punch my heart, I giggle, honey, that ain't it at all",
        "Back rank, back rank, bounce it to the beat",
        "Promotion on my mind and a pawn kissing my feet",
        "King in check again, he hiding under the bed",
        "Queen in the spotlight, put the crown upon my head",
    ]), (44, [
        "Sniper on my lap but I'm a lover, not a fighter",
        "Hold my lip gloss, baby, while I make the board brighter",
        "Drive-by in a lowrider, bouncing to the bass",
        "Neighbor pieces whistling when I'm shaking in my place",
        "Odd jobs? Honey, I don't lift a single finger",
        "I just smile at the bishop and he pays me like a singer",
        "Double move espresso, two steps and a dip",
        "Spin around the pawn and then I'm sliding off his hip",
        "Yugi in the graveyard asking for my card",
        "Told him I'm a rare one and I'm playing hard",
        "Beyblade spinning like my hips up in the club",
        "Pulled the cord too hard and now it's rolling in the tub",
        "Bishop wants a slow dance on the sunset cruise",
        "Honey, you're too pointy and you're pinching on my shoes",
        "Every piece is staring when I'm walking down the file",
        "Elongated legs and an elongated smile",
        "Tap me on the board and I'll open up my menu",
        "Move, inspect or date me, baby, pick a fancy venue",
        "Inspect me if you dare, I'm a riddle in a box",
        "Ten inches of heels and a dozen golden locks",
        "Black side, white side, I don't really mind",
        "As long as you are tall and you're treating me kind",
        "Whisper sweet nothings in algebraic notation",
        "Queen to h-five, baby, that's a situation",
        "Rook says he's sturdy and he'll never let me down",
        "But he only moves in straight lines and I'm the curve in town",
        "Shake it to the left side, shake it to the right",
        "Pieces doing all the work and I'm twerking through the night",
        "Gambit Goods and Gas got my favorite lip balm",
        "Pay me in Ward Charms, keep me safe and calm",
        "Ash in my hair from the boys who didn't make it",
        "Brush it off my shoulder, honey, I don't fake it",
    ]), (84, [
        "Velvet on the throne cause a queen deserves the best",
        "Pawns fanning palm leaves while the kingdom does the rest",
        "King wrote me a poem, it was mostly about check",
        "Told him I'm the queen, put your arms around my neck",
        "Every capture's a romance, every labyrinth's a kiss",
        "Every duel is a tango that you do not wanna miss",
        "Drop it like a pawn on the very first move",
        "Two squares forward and I'm locking in the groove",
        "Bishop on the dance floor sliding to the side",
        "Knight doing the L-step, honey, that's his pride",
        "My tiara's from the graveyard, Yugi lost the bet",
        "Heart of the cards, baby, still ain't got me yet",
        "Shake the board so hard all the pieces start to tumble",
        "Beyblade on the ceiling and the speakers start to rumble",
        "Pink slip in my garter, I collect them by the dozen",
        "Every car in town and a lowrider from my cousin",
        "Grab your Health Draught, honey, this is gonna be a night",
        "Mana for the morning cause we're dancing till it's light",
        "Little bit of glitter on the corners of the board",
        "Every single square is a dance floor I adored",
        "If you want to win me bring a bouquet and a song",
        "Make it elongated, honey, make it really long",
        "Checkmate is a feeling that I give you with a wink",
        "Leave you in the corner while I'm sipping on my drink",
        "Back rank bounce, honey, feel it in your knees",
        "Every piece on sixty-four is begging for me, please",
        "Back that marble up and let the bishops take a look",
        "Rook got so excited that he tumbled off his hook",
        "Queen of every color, I'm the sparkle and the shine",
        "The board is my runway and the rest is just a line",
        "So tap my tiara if you want another dance",
        "The queen is in the building and you never stood a chance",
    ])],
    "spoken": [(38, "Okay, DJ. Slow it down for the ladies."),
               (78, "Ladies, put your crowns up. All my queens in the back."),
               (117, "Mwah. That was the Back Rank Bounce."),
               (120, "Queen Cushy, signing off. Stay tall, boys.")],
}


# --- instruments ------------------------------------------------------------------

def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def place(buf, s, at):
    i = int(at * SR)
    if i >= len(buf) or i < 0:
        return
    end = min(len(buf), i + len(s))
    buf[i:end] += s[: end - i]


def kick(punch=110, decay=9):
    t = t_axis(0.35)
    f = 48 + punch * np.exp(-t * 28)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * decay) * 0.95


def snare(tone=190, length=0.25):
    t = t_axis(length)
    n = np.convolve(rng.standard_normal(len(t)), [1, -0.6], "same")
    return n * np.exp(-t * 18) * 0.45 + np.sin(2 * np.pi * tone * t) * np.exp(-t * 25) * 0.35


def clap():
    t = t_axis(0.2)
    n = np.convolve(rng.standard_normal(len(t)), [1, -1], "same") * 0.4
    env = np.exp(-t * 30) + 0.6 * np.exp(-np.maximum(t - 0.012, 0) * 30) * (t > 0.012)
    return n * env


def hat(open_=False):
    t = t_axis(0.25 if open_ else 0.05)
    n = np.convolve(rng.standard_normal(len(t)), [1, -2, 1], "same") * 0.22
    return n * np.exp(-t * (14 if open_ else 80))


def bass808(m, dur):
    t = t_axis(dur)
    f = hz(m - 12) * (1 + 0.06 * np.exp(-t * 20))
    s = np.tanh(np.sin(2 * np.pi * np.cumsum(f) / SR) * 1.8)
    return s * np.minimum(t / 0.01, 1) * np.exp(-t * 1.4) * 0.5


def keys(notes, dur):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for m in notes:
        f = hz(m + 12)
        out += np.sin(2 * np.pi * f * t) * np.exp(-t * 3.0) + 0.3 * np.sin(4 * np.pi * f * t) * np.exp(-t * 6)
    return out * 0.09


def pad(notes, dur, bright=0.6):
    """Slow-swelling string section: detuned saws with their highs rolled off."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for m in notes:
        for det in (-0.12, 0.0, 0.11):
            f = hz(m) * 2 ** (det / 12.0)
            for n in range(1, 9):
                out += np.sin(2 * np.pi * f * n * t + n * det * 5) / n * bright ** (n - 1)
    env = np.minimum(t / 0.6, 1.0) * np.clip((dur - t) / 0.5, 0, 1)
    return out * env * 0.018


def choir(notes, dur):
    """An 'aah' choir: harmonics shaped by two vowel formants."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for m in notes:
        f0 = hz(m)
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t)
        for n in range(1, 16):
            fn = f0 * n
            g = np.exp(-((fn - 750) / 260) ** 2) + 0.6 * np.exp(-((fn - 1150) / 300) ** 2) + 0.15 / n
            out += np.sin(2 * np.pi * np.cumsum(np.full_like(t, fn) * vib) / SR) * g
    env = np.minimum(t / 0.8, 1.0) * np.clip((dur - t) / 0.6, 0, 1)
    return out * env * 0.03


def brass(m, dur, loud=1.0):
    """A brass voice: a buzzy tone whose upper harmonics bloom as it's blown."""
    t = t_axis(dur)
    f = hz(m) * (1 + 0.003 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(t / 0.4, 1))
    phase = 2 * np.pi * np.cumsum(f) / SR
    bloom = np.minimum(t / 0.08, 1.0) * 0.7 + 0.25
    out = np.zeros_like(t)
    for n in range(1, 14):
        out += np.sin(phase * n) / n * bloom ** (n * 0.8)
    env = np.minimum(t / 0.05, 1.0) * np.clip((dur - t) / 0.12, 0, 1) * (0.85 + 0.15 * np.exp(-t * 4))
    return np.tanh(out * env * 1.4) * 0.16 * loud


def timpani(m, dur=1.2):
    t = t_axis(dur)
    f = hz(m - 12) * (1 + 0.02 * np.exp(-t * 8))
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR)
    roll = rng.standard_normal(len(t)) * 0.15 * np.exp(-t * 30)
    return (s * np.exp(-t * 2.5) + roll) * 0.55


def pluck(m, dur=0.35):
    t = t_axis(dur)
    f = hz(m + 12)
    s = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 12) + 0.25 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t * 20)
    return s * np.exp(-t * 9) * 0.12


def shaker():
    t = t_axis(0.06)
    n = np.convolve(rng.standard_normal(len(t)), [1, -2, 1], "same") * 0.08
    return n * np.exp(-t * 60) * np.minimum(t / 0.01, 1)


def reverb(x, seconds=1.6, mix=0.25):
    ir_t = t_axis(seconds)
    ir = rng.standard_normal(len(ir_t)) * np.exp(-ir_t * 4.0)
    ir[0] = 0
    wet = np.convolve(x, ir / np.sqrt(np.sum(ir ** 2)), "full")[: len(x)]
    return x + wet * mix


# --- beats ------------------------------------------------------------------------

def beat_diss(song, total):
    buf = np.zeros(int(total * SR))
    bar_len = song["bar"]
    step = bar_len / 16
    chords = [[48, 51, 55], [44, 48, 51], [41, 44, 48], [43, 47, 50]]
    for bar in range(song["bars"]):
        t0 = bar * bar_len
        brk = 72 <= bar < 76 or 36 <= bar < 40
        chord = chords[bar % 4]
        place(buf, keys(chord, bar_len * 0.45), t0)
        place(buf, keys(chord, bar_len * 0.4), t0 + step * 6)
        if bar < 2:
            continue
        place(buf, bass808(chord[0], bar_len * 0.6), t0)
        place(buf, bass808(chord[0] + (7 if bar % 2 else 0), bar_len * 0.3), t0 + step * 10)
        if brk:
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
    crackle = np.zeros(len(buf))
    idx = rng.integers(0, len(buf), int(total * 30))
    crackle[idx] = rng.uniform(-0.15, 0.15, len(idx))
    return buf + crackle


def beat_epic(song, total):
    buf = np.zeros(int(total * SR))
    orch = np.zeros_like(buf)
    bar_len = song["bar"]
    step = bar_len / 16
    # D minor: Dm - Bb - F - C, two bars each
    prog = [[50, 53, 57], [46, 50, 53], [53, 57, 60], [48, 52, 55]]
    brass_from = song["brass_from"]
    motif = [(0, 0, 3), (3, 1, 1), (4, 2, 4), (8, 0, 2), (10, 1, 2), (12, 2, 4)]  # (step, chord tone, length in steps)
    for bar in range(song["bars"]):
        t0 = bar * bar_len
        chord = prog[(bar // 2) % 4]
        quiet = 32 <= bar < 36 or 64 <= bar < 68
        if bar % 2 == 0:
            place(orch, pad([n - 12 for n in chord] + [chord[0]], bar_len * 2), t0)
            if bar >= 8:
                place(orch, choir([n + 12 for n in chord], bar_len * 2), t0)
        place(orch, timpani(chord[0]), t0)
        if not quiet:
            place(orch, timpani(chord[0] + 7, 0.8) * 0.7, t0 + step * 8)
        # strings ostinato from the second verse on
        if bar >= 36:
            for k in range(0, 16, 2):
                place(orch, pluck(chord[(k // 2) % 3] + 12, 0.3) * 0.8, t0 + k * step)
        # brass: the second half of the song
        if bar >= brass_from:
            loud = min(1.0, 0.45 + (bar - brass_from) * 0.08)
            for s, tone, length in motif:
                note = chord[tone] + (12 if bar % 4 >= 2 and tone == 2 else 0)
                place(orch, brass(note, length * step * 0.95, loud), t0 + s * step)
                place(orch, brass(note - 12, length * step * 0.95, loud * 0.6), t0 + s * step)
            if bar % 8 == 7:
                place(orch, brass(chord[0] + 12, bar_len * 0.9, loud * 1.2), t0 + step * 2)
        if bar < 4 or quiet or bar >= 96:
            continue
        place(buf, bass808(chord[0], bar_len * 0.55) * 0.9, t0)
        place(buf, kick(punch=90, decay=7), t0)
        place(buf, kick(punch=90, decay=7) * 0.8, t0 + step * 10)
        place(buf, snare(tone=160, length=0.4) * 1.1, t0 + step * 8)
        for k in range(0, 16, 4):
            place(buf, hat(), t0 + k * step + step * 2)
    return buf + reverb(orch, 2.2, 0.35)


def beat_bounce(song, total):
    buf = np.zeros(int(total * SR))
    bar_len = song["bar"]
    step = bar_len / 16
    # F minor: Fm - Db - Ab - Eb
    prog = [[53, 56, 60], [49, 53, 56], [56, 60, 63], [51, 55, 58]]
    hook = [0, 2, 1, 2, 0, 1, 2, 1]
    for bar in range(song["bars"]):
        t0 = bar * bar_len
        chord = prog[bar % 4]
        slow = 36 <= bar < 44 or 76 <= bar < 84
        # marimba-ish plucks on the off-beats
        for k in range(8):
            if k % 2 == 1 or bar % 2 == 0:
                place(buf, pluck(chord[hook[k]], 0.3), t0 + k * 2 * step + (step if k % 2 else 0))
        if bar < 4 or bar >= 116:
            continue
        place(buf, bass808(chord[0], bar_len * 0.35), t0)
        place(buf, bass808(chord[0], bar_len * 0.2), t0 + step * 6)
        place(buf, bass808(chord[0] + 7, bar_len * 0.2), t0 + step * 11)
        if slow:
            for k in (0, 8):
                place(buf, kick(punch=80), t0 + k * step)
            place(buf, clap() * 0.7, t0 + 12 * step)
            continue
        # dembow: four on the floor kick, the snare skipping on 3 6 11 14
        for k in (0, 4, 8, 12):
            place(buf, kick(punch=95, decay=11), t0 + k * step)
        for k in (3, 6, 11, 14):
            place(buf, snare(tone=240, length=0.15) * 0.75, t0 + k * step)
        place(buf, clap() * 0.6, t0 + 12 * step)
        for k in range(16):
            place(buf, shaker() * (1.0 if k % 2 else 0.6), t0 + k * step)
    return buf


SONGS = {
    "diss": {"title": "Long Boy Diss (Black Side Freestyle)", "artist": "MC Long Boy", "lyrics": DISS,
             "bpm": 90, "bars": 112, "voice": "rms", "pitch": 0.9, "echo": False, "beat": beat_diss, "vox": 0.6, "beat_gain": 0.55},
    "epic": {"title": "Coronation of the Long Boys", "artist": "Sir Ivory", "lyrics": EPIC,
             "bpm": 80, "bars": 100, "voice": "awb", "pitch": 0.92, "echo": True, "beat": beat_epic, "vox": 0.62, "beat_gain": 0.5, "brass_from": 50},
    "bounce": {"title": "Back Rank Bounce", "artist": "Queen Cushy", "lyrics": BOUNCE,
               "bpm": 100, "bars": 125, "voice": "slt", "pitch": 1.04, "echo": False, "beat": beat_bounce, "vox": 0.62, "beat_gain": 0.55},
}


# --- vocals and rendering -----------------------------------------------------------

def schedule(song):
    ly = song["lyrics"]
    lines = list(ly["intro"])
    for start, verse in ly["verses"]:
        lines += [(start + i, l) for i, l in enumerate(verse)]
    lines += ly["spoken"]
    lines.sort()
    texts = [l for _, l in lines]
    assert len(texts) == len(set(texts)), "a lyric repeats in " + song["title"]
    bars = [b for b, _ in lines]
    assert len(bars) == len(set(bars)), "two lines share a bar in " + song["title"]
    assert max(bars) < song["bars"] - 1
    return lines


def read_wav(path):
    with wave.open(path) as w:
        sr = w.getframerate()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float) / 32768.0
    if sr != SR:
        x = np.arange(int(len(data) * SR / sr)) * sr / SR
        data = np.interp(x, np.arange(len(data)), data)
    return data


def sing(song, text, slot, tmp):
    spoken = text
    for k, v in SPOKEN.items():
        spoken = spoken.replace(k, v)
    raw = os.path.join(tmp, "raw.wav")
    out = os.path.join(tmp, "out.wav")
    subprocess.run(["flite", "-voice", song["voice"], "-t", spoken, "-o", raw], check=True)
    with wave.open(raw) as w:
        dur = w.getnframes() / w.getframerate()
        rate = w.getframerate()
    pitch = song["pitch"]
    tempo = min(2.0, max(0.9, dur / pitch / slot))
    chain = "asetrate=%d,aresample=%d,atempo=%.4f,highpass=f=90" % (int(rate * pitch), SR, tempo)
    if song["echo"]:
        chain += ",aecho=0.8:0.5:90|180:0.35|0.2"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", raw, "-af", chain, out], check=True)
    v = read_wav(out)
    v = v / max(1e-6, np.max(np.abs(v)))
    # trim the synthesizer's silence so the line's start time is the first syllable
    loud = np.nonzero(np.abs(v) > 0.04)[0]
    if len(loud):
        v = v[max(0, loud[0] - int(0.01 * SR)): loud[-1] + int(0.05 * SR)]
    return np.tanh(v * 2.2) * song["vox"]


def render(sid):
    song = SONGS[sid]
    song["bar"] = 4 * 60.0 / song["bpm"]
    lines = schedule(song)
    total = song["bars"] * song["bar"] + 1.5
    mix = song["beat"](song, total) * song["beat_gain"]
    vox = np.zeros_like(mix)
    timings = []
    spoken_bars = {b for b, _ in song["lyrics"]["spoken"]} | {b for b, _ in song["lyrics"]["intro"]}
    with tempfile.TemporaryDirectory() as tmp:
        for bar, text in lines:
            start = bar * song["bar"] + 0.03
            slot = song["bar"] * (1.85 if bar in spoken_bars else 0.93)
            v = sing(song, text, slot, tmp)
            place(vox, v, start)
            place(vox, v * 0.25, start + 0.022)
            timings.append((start, start + len(v) / SR, text))
    mix += vox
    mix *= np.clip((total - np.arange(len(mix)) / SR) / 1.5, 0, 1)
    mix = np.tanh(mix * 1.1)
    mix = mix / np.max(np.abs(mix)) * 0.92
    out_dir = os.path.join(ROOT, "assets", "audio", "songs")
    os.makedirs(out_dir, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "mix.wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((mix * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "2",
                        os.path.join(out_dir, sid + ".ogg")], check=True)
    gd = ["## Generated by tools/gen_songs.py: when each line of \"%s\" is sung." % song["title"],
          "extends RefCounted", "",
          'const TITLE := "%s"' % song["title"], 'const ARTIST := "%s"' % song["artist"],
          "const LENGTH := %.2f" % total, "", "const LINES := ["]
    for s, e, text in timings:
        gd.append('\t[%.2f, %.2f, "%s"],' % (s, e, text.replace('"', '\\"')))
    gd.append("]")
    with open(os.path.join(ROOT, "scripts", "title", "lyrics_%s.gd" % sid), "w") as f:
        f.write("\n".join(gd) + "\n")
    overlaps = sum(1 for a, b in zip(timings, timings[1:]) if a[1] > b[0])
    print("%-7s %5.1f s  %3d lines  %d overlapping" % (sid, total, len(timings), overlaps))


if __name__ == "__main__":
    for sid in (sys.argv[1:] or list(SONGS)):
        render(sid)
