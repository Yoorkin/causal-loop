"""Capture the actual teaching-heart animation and verify its phase ordering."""
import io
import json
import time
from pathlib import Path
from PIL import Image
from playwright.sync_api import sync_playwright

out = Path(__file__).resolve().parents[1] / 'artifacts' / 'qa'
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chromium', headless=True)
    page = browser.new_page(viewport={'width': 1280, 'height': 900})
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.goto('http://127.0.0.1:8000/')
    page.wait_for_function('document.querySelector("canvas").dataset.state')
    page.locator('#debug-mode').check()

    def read():
        return page.evaluate('''() => {
          const d = document.querySelector('canvas').dataset;
          return {s:JSON.parse(d.state), phase:d.wavePhase, heart:d.heartFlightPhase,
            opacity:+d.heartFlightOpacity, x:+d.heartFlightX, y:+d.heartFlightY,
            minute:+d.minuteDegrees, shakeX:+d.clockShakeX, shakeY:+d.clockShakeY};
        }''')

    def wait(expr):
        page.wait_for_function('() => {const d=document.querySelector("canvas").dataset; const s=JSON.parse(d.state); return ' + expr + ';}', timeout=20000)

    page.keyboard.press('2', delay=80)
    page.keyboard.down('Space')
    wait('s.tick >= 1074')
    frames, stamps, samples = [], [], []
    captured = set()
    started = time.monotonic()
    while time.monotonic() - started < 12:
        r = read()
        pixels = Image.open(io.BytesIO(page.locator('#stage').screenshot())).convert('RGB')
        stamps.append(time.monotonic())
        samples.append(r)
        frames.append(pixels.resize((840, 465)))
        name = None
        if r['heart'] == 'flying' and r['y'] > 130:
            name = 'heart-flying-to-clock'
        if r['heart'] == 'blinking' and r['opacity'] > .65:
            name = 'heart-in-front-of-clock'
        if r['phase'] == 'fading' and 280 < r['minute'] < 320:
            name = 'heart-triggered-rewind'
        if name and name not in captured:
            pixels.save(out / (name + '.png'))
            captured.add(name)
        if r['s']['life'] == 2 and r['phase'] == 'growing':
            break
        page.wait_for_timeout(20)
    page.keyboard.up('Space')
    assert all(any(r['heart'] == phase for r in samples) for phase in ['waiting', 'flying', 'blinking'])
    assert len(captured) == 3, captured
    for r in samples:
        if r['heart'] in ['waiting', 'flying', 'blinking']:
            assert r['phase'] == 'holding' and r['minute'] == 360
        if r['phase'] == 'fading':
            assert r['heart'] == 'none' and r['opacity'] == 0
    early = [r for r in samples if r['phase'] == 'fading' and r['minute'] > 180]
    late = [r for r in samples if r['phase'] == 'fading' and r['minute'] < 150]
    assert any(abs(r['shakeX']) + abs(r['shakeY']) > .1 for r in early)
    assert late and all(r['shakeX'] == r['shakeY'] == 0 for r in late)
    assert samples[-1]['s']['life'] == 2
    durations = [max(10, round((b-a)*100)*10) for a,b in zip(stamps, stamps[1:])] + [500]
    frames[0].save(out / 'heart-rewind.gif', save_all=True, append_images=frames[1:], duration=durations, loop=0)

    # Pause freezes the heart as well as the world; debug switching clears it.
    page.keyboard.press('2', delay=80)
    page.wait_for_timeout(50)
    page.keyboard.down('Space')
    wait('d.heartFlightPhase == "flying"')
    page.keyboard.press('Escape', delay=50)
    paused = read()
    page.wait_for_timeout(200)
    assert read() == paused
    page.keyboard.up('Space')
    page.keyboard.press('3', delay=80)
    assert read()['heart'] == 'none'
    page.keyboard.down('Space')
    wait('d.wavePhase == "holding"')
    assert read()['heart'] == 'none'
    page.keyboard.up('Space')
    assert not errors, errors
    result = {'passed': True, 'heart_phases': ['waiting', 'flying', 'blinking', 'vanished', 'rewind'],
              'clock_waits_for_heart': True, 'rewind_shake_settles_after_two_seconds': True,
              'pause_and_debug_reset': True, 'other_levels_skip_heart_animation': True, 'errors': errors}
    (out / 'heart-rewind-results.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result), flush=True)
    browser.close()
