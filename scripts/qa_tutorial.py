"""Play the tutorial and inspect teaching pauses through real keys/read-only state."""
import io
import json
import time
from pathlib import Path
from PIL import Image
from playwright.sync_api import sync_playwright

out = Path(__file__).resolve().parents[1] / 'artifacts' / 'qa'
out.mkdir(parents=True, exist_ok=True)
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chromium', headless=True)
    page = browser.new_page(viewport={'width': 1280, 'height': 900})
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.goto('http://127.0.0.1:8000/')
    page.wait_for_function('document.querySelector("canvas").dataset.state')
    page.locator('#debug-mode').check()
    page.locator('#canvas').click()

    def read():
        return page.evaluate('''() => {
          const d = document.querySelector('canvas').dataset;
          return {s:JSON.parse(d.state), phase:d.wavePhase, mode:d.mode,
            minute:+d.minuteDegrees, hour:+d.hourDegrees,
            tick:+d.simulationTick, speed:+d.speed};
        }''')

    def wait(expr):
        page.wait_for_function('() => {const d=document.querySelector("canvas").dataset; const s=JSON.parse(d.state); return ' + expr + ';}', timeout=20000)

    def press(key):
        page.keyboard.press(key, delay=80)
        page.wait_for_timeout(50)

    def shot(name):
        raw = page.locator('#stage').screenshot(path=str(out / (name + '.png')))
        return Image.open(io.BytesIO(raw)).convert('RGB')

    wait('s.actors[0].grounded')
    initial = read()
    assert initial['s']['level'] == 0 and initial['s']['max_lives'] == 1
    assert initial['minute'] > 0 and abs(initial['hour'] - initial['minute']/12) < 1e-7
    start = shot('tutorial-start')
    assert start.getpixel((560, 41)) == (237, 83, 99)
    assert start.getpixel((954, 528)) != (237, 83, 99)
    page.keyboard.down('Space')
    page.wait_for_timeout(400)
    assert read()['speed'] == 6 and read()['minute'] > initial['minute']
    page.keyboard.up('Space')
    page.keyboard.down('d')
    wait('s.actors[0].x >= 3600')
    press('w')
    wait('s.actors[0].grounded && s.actors[0].y == 3920')
    wait('s.actors[0].x >= 5400')
    press('w')
    wait('s.actors[0].grounded && s.actors[0].x >= 7000')
    page.keyboard.up('d')
    assert read()['s']['actors'][0]['y'] == 3120
    shot('tutorial-drop-platform')
    page.wait_for_timeout(250)
    assert read()['s']['actors'][0]['y'] == 3120
    press('s')
    wait('s.actors[0].grounded && s.actors[0].y == 5220')
    shot('tutorial-landed')
    page.keyboard.down('d')
    wait('s.actors[0].x >= 7600')
    page.keyboard.down('s')
    wait('s.actors[0].x >= 8540')
    page.keyboard.up('s')
    wait('s.heart_collected')
    page.keyboard.up('d')
    assert read()['s']['max_lives'] == 2
    assert read()['s']['remaining_lives'] == 1
    picked = shot('tutorial-empty-container-collected')
    assert picked.getpixel((544, 41)) == (237, 83, 99)
    assert picked.getpixel((576, 41)) != (237, 83, 99)
    page.keyboard.down('d')
    wait('s.level == 1')
    page.keyboard.up('d')
    assert read()['mode'] == 'transition' and read()['tick'] == 0
    wait('d.mode == "play"')
    assert read()['s']['max_lives'] == 2
    assert read()['s']['remaining_lives'] == 2
    print('Tutorial: two jumps, S drop, S + D crawl, empty container and full refill on completion passed.', flush=True)

    page.keyboard.down('Space')
    wait('d.wavePhase == "holding"')
    hold_start = time.monotonic()
    held = read()
    assert held['minute'] == 360
    wait('d.heartFlightPhase == "flying" && +d.heartFlightY > 80')
    consumed = shot('teaching-heart-consumed')
    assert held['minute'] == 360
    assert consumed.getpixel((544, 41)) == (237, 83, 99)
    assert consumed.getpixel((576, 41)) != (237, 83, 99)
    wait('d.wavePhase == "fading"')
    hold_duration = time.monotonic() - hold_start
    assert 1.5 <= hold_duration <= 1.9
    fade_start = time.monotonic()
    wait('d.wavePhase == "resetting"')
    fade_duration = time.monotonic() - fade_start
    assert 3.9 <= fade_duration <= 4.3
    reset_start = time.monotonic()
    reset = read()
    assert reset['s']['life'] == 1 and reset['tick'] == 0
    assert reset['minute'] == 0 and reset['hour'] == 30
    shot('teaching-clock-zero')
    page.wait_for_timeout(450)
    assert read() == reset
    page.keyboard.down('d')
    wait('s.life == 2 && d.mode == "play"')
    reset_duration = time.monotonic() - reset_start
    assert 1.5 <= reset_duration <= 1.9
    reborn = read()
    assert reborn['tick'] < 5 and reborn['phase'] == 'growing'
    shot('teaching-immediate-rebirth')
    page.wait_for_timeout(150)
    assert read()['tick'] - reborn['tick'] >= 5
    assert read()['s']['actors'][1]['x'] > reborn['s']['actors'][1]['x']
    assert read()['speed'] == 1
    page.keyboard.up('d')
    page.keyboard.up('Space')
    page.wait_for_timeout(50)
    print('Teaching: heart flight, 4s rewind, 1.6s zero pause; immediate controllable rebirth.', flush=True)

    for key in [1, 2, 3, 4, 5]:
        press(str(key))
        r = read()
        assert r['s']['level'] == [0, 1, 3, 2, 4][key - 1]
        assert r['s']['life'] == 1 and r['s']['history_lengths'] == []
        assert abs(r['hour'] - ((key - 1)*30 + r['minute']/12)) < 1e-7
        if key == 1:
            assert r['s']['max_lives'] == 1 and not r['s']['heart_collected']
        else:
            assert r['s']['max_lives'] == 2
        assert r['s']['inventory']['time_acceleration'] == (key >= 3)
    press('3')
    page.keyboard.down('Space')
    wait('d.wavePhase == "fading"')
    normal_start = time.monotonic()
    assert read()['tick'] == 0
    wait('s.life == 2 && d.mode == "play"')
    normal_duration = time.monotonic() - normal_start
    assert 1.0 <= normal_duration <= 1.4
    page.keyboard.up('Space')
    page.wait_for_timeout(50)
    page.reload()
    wait('s.level == 0')
    page.locator('#debug-mode').check()
    page.locator('#canvas').click()
    page.keyboard.down('Space')
    wait('s.outcome == "Lost"')
    assert read()['s']['life'] == 1 and read()['minute'] == 360
    page.keyboard.up('Space')
    assert not errors, errors
    result = {'passed': True, 'debug_keys': {'1': 'tutorial', '2': 'bridge', '3': 'three gates', '4': 'reciprocal gates', '5': 'falling crates'},
              'post_impact_hold_seconds': hold_duration, 'rewind_seconds': fade_duration, 'heart_leaves_hud_before_rewind': True, 'clock_zero_hold_seconds': reset_duration, 'immediate_rebirth': True,
              'normal_rewind_seconds': normal_duration, 'errors': errors,
              'verification': 'Real keyboard inputs and rendered pixels; no state injection.'}
    (out / 'tutorial-results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
    print(json.dumps(result, ensure_ascii=False), flush=True)
    browser.close()
