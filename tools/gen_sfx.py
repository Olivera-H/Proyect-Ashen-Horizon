#!/usr/bin/env python3
"""Sintetiza los efectos de sonido de Ashen Horizon por codigo (numpy + scipy).
Salida: assets/audio/sfx/*.wav (mono, 22050 Hz, 16 bit).
Uso: python3 tools/gen_sfx.py"""
import os
import wave

import numpy as np
from scipy import signal

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "sfx")
RNG = np.random.default_rng(1234)


# ------------------------------------------------------------------ bloques
def t_(d):
    return np.arange(int(SR * d)) / SR


def noise(d):
    return RNG.uniform(-1, 1, int(SR * d))


def env(n, a=0.005, d=0.1, sus=0.0, r=0.05):
    """Envolvente ADSR simple sobre n muestras (tiempos en s)."""
    e = np.zeros(n)
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na, endpoint=False) if na else 0
    nd = min(nd, n - na)
    e[na:na + nd] = np.linspace(1, sus, nd, endpoint=False) if nd else 0
    e[na + nd:] = sus
    nr = min(nr, n)
    if nr:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def decay(n, tau):
    return np.exp(-np.arange(n) / SR / tau)


def lp(x, fc, order=2):
    b, a = signal.butter(order, min(fc, SR / 2 - 100) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR / 2 - 100) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def sine(freq, d, phase=0.0):
    t = t_(d)
    f = np.broadcast_to(freq, t.shape) if np.ndim(freq) == 0 else freq
    return np.sin(2 * np.pi * np.cumsum(f) / SR + phase)


def sweep(f0, f1, d, curve=1.0):
    k = np.linspace(0, 1, int(SR * d)) ** curve
    return sine(f0 + (f1 - f0) * k, d)


def saw(freq, d):
    t = t_(d)
    f = np.broadcast_to(freq, t.shape) if np.ndim(freq) == 0 else freq
    ph = (np.cumsum(f) / SR) % 1.0
    return 2 * ph - 1


def square(freq, d):
    return np.sign(sine(freq, d))


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


ONLY = None
if "--only" in __import__("sys").argv:   # regenera solo estos sonidos (no pisa archivos reemplazados a mano)
    ONLY = set(__import__("sys").argv[__import__("sys").argv.index("--only") + 1].split(","))


def save(name, x, peak=0.9):
    if ONLY is not None and name not in ONLY:
        return
    x = norm(x, peak)
    x = np.clip(x, -1, 1)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


# ------------------------------------------------------------------ sonidos
def footsteps():
    for i, (fc, f0) in enumerate(((900, 90), (1200, 110), (700, 80), (1000, 100))):
        n = int(0.14 * SR)
        thump = sweep(f0 * 1.6, f0 * 0.7, 0.14) * decay(n, 0.03)
        crunch = lp(noise(0.14), fc) * decay(n, 0.025)
        grit = hp(noise(0.14), 3000) * decay(n, 0.012) * 0.25
        save("step_%d" % i, mix(thump * 0.9, crunch * 0.8, grit), 0.55)


def melee():
    n = int(0.2 * SR)
    sw = bp(noise(0.2), 400, 3500) * np.sin(np.linspace(0, np.pi, n)) ** 1.5
    save("swing", sw, 0.6)
    n = int(0.16 * SR)
    save("hit", mix(sweep(180, 60, 0.16) * decay(n, 0.04), lp(noise(0.16), 2200) * decay(n, 0.03), hp(noise(0.16), 2500) * decay(n, 0.008) * 0.4), 0.9)
    n = int(0.12 * SR)
    save("hit_metal", mix(sine(1850, 0.12) * decay(n, 0.03), sine(2750, 0.12) * decay(n, 0.02) * 0.5, noise(0.12) * decay(n, 0.01) * 0.4), 0.7)
    save("dodge", bp(noise(0.22), 300, 2600) * np.sin(np.linspace(0, np.pi, int(0.22 * SR))) * 0.8, 0.5)


def guns():
    # pistola: chasquido seco + estampido corto
    n = int(0.4 * SR)
    crack = hp(noise(0.4), 1500) * decay(n, 0.012)
    boom = lp(noise(0.4), 700) * decay(n, 0.08)
    thump = sweep(160, 45, 0.4) * decay(n, 0.07)
    tail = lp(noise(0.4), 1800) * decay(n, 0.18) * 0.25
    save("shot_pistola", mix(crack * 0.9, boom * 0.9, thump * 0.9, tail), 0.95)
    # escopeta: mas grave y larga
    n = int(0.7 * SR)
    crack = hp(noise(0.7), 900) * decay(n, 0.02)
    boom = lp(noise(0.7), 500) * decay(n, 0.16)
    thump = sweep(120, 30, 0.7) * decay(n, 0.14)
    tail = lp(noise(0.7), 1200) * decay(n, 0.35) * 0.3
    save("shot_escopeta", mix(crack, boom * 1.2, thump * 1.1, tail), 1.0)
    pump = mix(square(130, 0.05) * 0.5, noise(0.05) * 0.5)
    save("pump", np.concatenate([bp(pump, 400, 3000) * env(len(pump), 0.001, 0.04), np.zeros(int(0.08 * SR)),
                                 bp(pump, 300, 2500) * env(len(pump), 0.001, 0.04)]), 0.6)
    # fusil: chasquido corto y seco
    n = int(0.22 * SR)
    crack = hp(noise(0.22), 1800) * decay(n, 0.01)
    boom = lp(noise(0.22), 900) * decay(n, 0.05)
    thump = sweep(200, 70, 0.22) * decay(n, 0.04)
    save("shot_fusil", mix(crack, boom * 0.8, thump * 0.8, lp(noise(0.22), 2500) * decay(n, 0.09) * 0.2), 0.9)
    # sin municion
    n = int(0.07 * SR)
    save("click_empty", mix(square(900, 0.07) * decay(n, 0.01), noise(0.07) * decay(n, 0.006) * 0.6), 0.5)


def zombies():
    def growl(d, f0, f1, wob, seed=0):
        n = int(d * SR)
        t = t_(d)
        f = np.linspace(f0, f1, n) * (1 + 0.06 * np.sin(2 * np.pi * wob * t))
        src = saw(f, d) * 0.7 + saw(f * 1.51, d) * 0.3
        src = lp(src, 900) + bp(noise(d), 300, 1400) * 0.35
        form = bp(src, 350, 900) * 1.2 + bp(src, 1200, 2200) * 0.4
        return form * env(n, 0.06, 0.15, 0.7, d * 0.4) * (0.7 + 0.3 * np.sin(2 * np.pi * (wob * 1.7) * t))
    save("zombie_growl_a", growl(0.9, 95, 70, 7), 0.8)
    save("zombie_growl_b", growl(0.75, 120, 85, 9), 0.8)
    save("zombie_growl_c", growl(1.1, 80, 55, 5), 0.8)
    n = int(0.3 * SR)
    save("zombie_hurt", growl(0.3, 150, 90, 12) * 0.9 + lp(noise(0.3), 1500) * decay(n, 0.05) * 0.3, 0.8)
    n = int(0.28 * SR)
    save("zombie_attack", growl(0.28, 110, 140, 14) + bp(noise(0.28), 500, 3000) * env(n, 0.01, 0.1, 0.3, 0.1) * 0.4, 0.8)
    n = int(0.9 * SR)
    die = growl(0.9, 130, 40, 6) * env(n, 0.02, 0.4, 0.3, 0.4)
    gurgle = bp(noise(0.9), 200, 700) * np.abs(np.sin(2 * np.pi * 14 * t_(0.9))) * decay(n, 0.35) * 0.5
    thud = np.concatenate([np.zeros(int(0.45 * SR)), sweep(90, 40, 0.3) * decay(int(0.3 * SR), 0.08)])
    save("zombie_die", mix(die, gurgle, thud * 0.9), 0.9)


def player():
    n = int(0.25 * SR)
    save("hurt", mix(sweep(260, 150, 0.25) * decay(n, 0.07) * 0.5, lp(noise(0.25), 1500) * decay(n, 0.05) * 0.7, bp(noise(0.25), 400, 1200) * decay(n, 0.08) * 0.4), 0.8)
    n = int(1.2 * SR)
    drop = sweep(330, 70, 1.2, 0.6) * env(n, 0.01, 0.6, 0.2, 0.5) * 0.6
    low = sweep(80, 35, 1.2) * decay(n, 0.5)
    save("death", mix(drop, low, lp(noise(1.2), 600) * decay(n, 0.25) * 0.5), 0.9)
    n = int(1.4 * SR)
    beat = np.zeros(n)
    for start in (0.0, 0.28, 0.9, 1.18):
        s = int(start * SR)
        thump = sweep(70, 40, 0.18) * decay(int(0.18 * SR), 0.05)
        beat[s:s + len(thump)] += thump
    save("heartbeat", beat, 0.8)


def items():
    def blip(f, d=0.08):
        n = int(d * SR)
        return (sine(f, d) + 0.3 * sine(f * 2, d)) * env(n, 0.003, d * 0.5, 0.2, d * 0.4)
    save("pickup", np.concatenate([blip(660), blip(990, 0.12)]), 0.6)
    save("pickup_key", np.concatenate([blip(523), blip(659), blip(784), blip(1047, 0.2)]), 0.6)
    n = int(0.35 * SR)
    save("note", hp(lp(noise(0.35), 5000), 1500) * (0.5 + 0.5 * np.sin(2 * np.pi * 18 * t_(0.35)) ** 2) * env(n, 0.02, 0.1, 0.5, 0.12), 0.45)
    n = int(0.45 * SR)
    rust = hp(lp(noise(0.45), 4500), 1200) * env(n, 0.03, 0.2, 0.3, 0.1) * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * t_(0.45)))
    save("heal", mix(rust * 0.8, np.concatenate([np.zeros(int(0.25 * SR)), blip(880, 0.18) * 0.5, blip(1320, 0.2) * 0.4])), 0.6)
    n = int(0.32 * SR)
    chew = lp(noise(0.32), 2500) * (np.abs(np.sin(2 * np.pi * 9 * t_(0.32))) ** 2) * env(n, 0.01, 0.1, 0.6, 0.08)
    save("eat", chew, 0.7)
    n = int(0.5 * SR)
    gulp = np.zeros(n)
    for s in (0.05, 0.22, 0.38):
        k = int(s * SR)
        g = sweep(180, 90, 0.1) * decay(int(0.1 * SR), 0.04)
        gulp[k:k + len(g)] += g
    save("drink", gulp + bp(noise(0.5), 600, 2000) * 0.1 * env(n, 0.02, 0.2, 0.3, 0.2), 0.6)
    n = int(0.3 * SR)
    save("repair", mix(sine(2400, 0.3) * decay(n, 0.04), sine(3600, 0.3) * decay(n, 0.025) * 0.4, noise(0.3) * decay(n, 0.01) * 0.5), 0.6)
    n = int(0.16 * SR)
    save("equip", mix(bp(noise(0.16), 1000, 5000) * decay(n, 0.02), sine(1500, 0.16) * decay(n, 0.03) * 0.5, sweep(250, 120, 0.16) * decay(n, 0.04) * 0.6), 0.6)
    n = int(0.06 * SR)
    save("flashlight", mix(square(1300, 0.06) * decay(n, 0.008), noise(0.06) * decay(n, 0.005) * 0.4), 0.45)
    n = int(0.7 * SR)
    mk = hp(lp(noise(0.7), 3000), 300) * env(n, 0.05, 0.25, 0.3, 0.2) * 0.6
    save("mask_on", mix(mk, np.concatenate([np.zeros(int(0.35 * SR)), sine(180, 0.3) * env(int(0.3 * SR), 0.02, 0.1, 0.4, 0.15) * 0.5])), 0.7)
    n = int(0.3 * SR)
    save("cough", mix(lp(noise(0.3), 1800) * env(n, 0.005, 0.07, 0.2, 0.15), sweep(260, 120, 0.3) * decay(n, 0.07) * 0.6), 0.7)


def doors():
    n = int(0.9 * SR)
    slide = bp(noise(0.9), 200, 1800) * env(n, 0.05, 0.3, 0.5, 0.25) * (0.7 + 0.3 * np.sin(2 * np.pi * 23 * t_(0.9)))
    servo = saw(sweep(140, 260, 0.9) * 0 + np.linspace(140, 260, n), 0.9) * 0.0
    motor = lp(saw(np.linspace(110, 190, n), 0.9), 700) * env(n, 0.08, 0.3, 0.5, 0.3) * 0.45
    clunk = np.concatenate([np.zeros(int(0.02 * SR)), sweep(160, 60, 0.15) * decay(int(0.15 * SR), 0.04)])
    clunk2 = np.concatenate([np.zeros(int(0.72 * SR)), sweep(140, 60, 0.15) * decay(int(0.15 * SR), 0.04)])
    save("door_open", mix(slide * 0.7, motor, clunk * 0.9, clunk2 * 0.8, servo), 0.8)
    n = int(0.3 * SR)
    save("door_locked", mix(sweep(140, 70, 0.3) * decay(n, 0.05), sine(520, 0.3) * decay(n, 0.04) * 0.5, noise(0.3) * decay(n, 0.01) * 0.4), 0.7)
    d = 0.1
    n = int(d * SR)
    beep = lambda f: (square(f, d) * 0.5 + sine(f, d)) * env(n, 0.003, 0.05, 0.4, 0.03)
    save("access_ok", np.concatenate([beep(880), np.zeros(int(0.03 * SR)), beep(1320)]), 0.55)
    save("access_denied", np.concatenate([beep(300), np.zeros(int(0.04 * SR)), beep(240)]), 0.55)
    n = int(0.5 * SR)
    key = mix(sine(2200, 0.5) * decay(n, 0.05), sine(3300, 0.5) * decay(n, 0.04) * 0.5, noise(0.5) * decay(n, 0.008) * 0.3)
    key2 = np.concatenate([np.zeros(int(0.18 * SR)), sine(1800, 0.3) * decay(int(0.3 * SR), 0.05)])
    save("key_turn", mix(key, key2 * 0.7), 0.6)


def ambience():
    # lluvia: ruido filtrado con gotas, ciclo sin costura (4 s)
    d = 4.0
    n = int(d * SR)
    base = bp(noise(d), 800, 7000, 1) * 0.55 + hp(noise(d), 5000) * 0.25
    drops = np.zeros(n)
    for _ in range(260):
        k = RNG.integers(0, n - 300)
        tick = hp(noise(0.012), 3000) * decay(int(0.012 * SR), 0.003)
        drops[k:k + len(tick)] += tick * RNG.uniform(0.2, 0.9)
    x = base + drops * 0.9
    fade = int(0.25 * SR)
    x[:fade] = x[:fade] * np.linspace(0, 1, fade) + x[-fade:] * np.linspace(1, 0, fade)
    save("rain_loop", x[:-fade], 0.5)
    # viento / toxico: zumbido grave
    d = 4.0
    n = int(d * SR)
    w = lp(noise(d), 380) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.35 * t_(d)))
    x = w[:-fade]
    save("wind_loop", x, 0.35)


def alarm():
    d = 1.6
    n = int(d * SR)
    f = np.where((np.arange(n) / SR % 0.8) < 0.4, 720.0, 960.0)
    x = lp(square(f, d) * 0.5 + saw(f, d) * 0.5, 2600) * env(n, 0.01, 0.1, 0.9, 0.05)
    save("alarm", x, 0.6)
    n = int(1.4 * SR)
    sweep_up = sweep(120, 900, 1.4, 1.5) * env(n, 0.05, 0.5, 0.6, 0.3)
    save("horde_rise", mix(sweep_up * 0.5, lp(noise(1.4), 900) * env(n, 0.2, 0.5, 0.5, 0.4) * 0.5), 0.7)


def ui():
    d = 0.05
    n = int(d * SR)
    save("ui_click", (sine(1400, d) * 0.6 + square(700, d) * 0.2) * env(n, 0.002, 0.02, 0.2, 0.02), 0.4)
    d = 0.14
    n = int(d * SR)
    save("ui_open", sweep(500, 900, d) * env(n, 0.005, 0.07, 0.3, 0.05), 0.45)
    save("ui_close", sweep(900, 450, d) * env(n, 0.005, 0.07, 0.3, 0.05), 0.45)
    d = 0.09
    n = int(d * SR)
    save("ui_blip", sine(1100, d) * env(n, 0.003, 0.04, 0.2, 0.04), 0.3)
    d = 0.5
    n = int(d * SR)
    chord = mix(*[sine(f, d) * env(n, 0.01, 0.2, 0.5, 0.25) for f in (330, 392, 494)])
    save("ui_start", chord, 0.6)
    save("ui_respawn", np.concatenate([sine(392, 0.12) * env(int(0.12 * SR), 0.005, 0.06, 0.3, 0.05),
                                       sine(523, 0.12) * env(int(0.12 * SR), 0.005, 0.06, 0.3, 0.05),
                                       sine(659, 0.25) * env(int(0.25 * SR), 0.005, 0.1, 0.4, 0.12)]), 0.55)


def farm():
    n = int(0.3 * SR)
    dig = mix(lp(noise(0.3), 900) * env(n, 0.01, 0.1, 0.3, 0.12), sweep(140, 70, 0.3) * decay(n, 0.06) * 0.7)
    save("plant", mix(dig, hp(noise(0.3), 3500) * decay(n, 0.015) * 0.2), 0.6)
    n = int(0.5 * SR)
    rustle = bp(noise(0.5), 1500, 6000) * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t_(0.5)) ** 2) * env(n, 0.02, 0.2, 0.3, 0.2)
    pop = np.concatenate([np.zeros(int(0.22 * SR)), sine(620, 0.12) * decay(int(0.12 * SR), 0.03), sine(930, 0.18) * decay(int(0.18 * SR), 0.05) * 0.8])
    save("harvest", mix(rustle * 0.6, pop * 0.7), 0.6)


def main():
    footsteps(); melee(); guns(); zombies(); player(); items(); doors(); ambience(); alarm(); ui(); farm()
    files = sorted(f for f in os.listdir(OUT) if f.endswith(".wav"))
    size = sum(os.path.getsize(os.path.join(OUT, f)) for f in files)
    print("%d sonidos, %.1f MB en %s" % (len(files), size / 1e6, os.path.normpath(OUT)))


if __name__ == "__main__":
    main()
