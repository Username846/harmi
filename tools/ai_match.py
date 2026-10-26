#!/usr/bin/env python3
"""Measures the game's chess AI by playing matches through tests/uci_engine.gd.

  python3 tools/ai_match.py A B [games] [jobs]

A and B are "level0".."level2" (the game's AI) or "sf1320" (Stockfish with
UCI_LimitStrength at that Elo; 1320 is its floor). Colours alternate. Prints
A's score and the Elo gap it implies. Needs python-chess, Stockfish and the
Godot binary in $GODOT. Games over 300 plies are scored as draws.
"""
import math
import os
import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor

import chess
import chess.engine

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def open_engine(name):
    if name.startswith("level"):
        cmd = [os.environ["GODOT"], "--headless", "--path", ROOT, "-s", "tests/uci_engine.gd", "--", "level=" + name[5:]]
        return chess.engine.SimpleEngine.popen_uci(cmd, stderr=subprocess.DEVNULL)
    e = chess.engine.SimpleEngine.popen_uci(os.environ.get("STOCKFISH", "/usr/games/stockfish"))
    e.configure({"UCI_LimitStrength": True, "UCI_Elo": int(name[2:]), "Threads": 1})
    return e


def play(args):
    a, b, a_white = args
    ea, eb = open_engine(a), open_engine(b)
    board = chess.Board()
    try:
        while not board.is_game_over(claim_draw=True) and board.ply() < 300:
            eng = ea if (board.turn == chess.WHITE) == a_white else eb
            board.push(eng.play(board, chess.engine.Limit(time=0.2)).move)
    finally:
        ea.quit()
        eb.quit()
    res = board.result(claim_draw=True)
    outcome = board.outcome(claim_draw=True)
    why = outcome.termination.name.lower() if outcome else "ply limit"
    if res in ("*", "1/2-1/2"):
        return 0.5, why
    white_won = res == "1-0"
    return (1.0 if white_won == a_white else 0.0), why


def main():
    a, b = sys.argv[1], sys.argv[2]
    games = int(sys.argv[3]) if len(sys.argv) > 3 else 20
    jobs = int(sys.argv[4]) if len(sys.argv) > 4 else 2
    with ProcessPoolExecutor(jobs) as pool:
        played = list(pool.map(play, [(a, b, i % 2 == 0) for i in range(games)]))
    results = [r for r, _ in played]
    endings = {}
    for _, why in played:
        endings[why] = endings.get(why, 0) + 1
    score = sum(results) / len(results)
    wins = results.count(1.0)
    draws = results.count(0.5)
    p = min(max(score, 0.01), 0.99)
    gap = -400 * math.log10(1 / p - 1)
    print("%s vs %s: +%d =%d -%d  score %.0f%%  -> %s is %+d Elo vs %s"
          % (a, b, wins, draws, len(results) - wins - draws, score * 100, a, gap, b))
    print("  endings: " + ", ".join("%s %d" % kv for kv in sorted(endings.items())))


if __name__ == "__main__":
    main()
