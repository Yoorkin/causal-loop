"""Every room must retain Game Over and retry the same room; refresh begins a new unsaved run."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

out = Path(__file__).resolve().parents[1] / 'artifacts' / 'qa'
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chromium', headless=True)
    page = browser.new_page(viewport={'width': 1280, 'height': 900})
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.goto('http://127.0.0.1:8000/')
    page.wait_for_function('document.querySelector("canvas").dataset.state')

    def read():
        return page.evaluate('''() => {const d=document.querySelector('canvas').dataset;
          return {s:JSON.parse(d.state), mode:d.mode, speed:+d.speed, opacity:+d.gameOverOpacity};}''')

    def wait(expr):
        page.wait_for_function('() => {const d=document.querySelector("canvas").dataset; const s=JSON.parse(d.state); return ' + expr + ';}', timeout=20000)

    results = []
    for number, level, lives in [(1, 0, 1), (2, 1, 2), (3, 3, 2), (4, 2, 2)]:
        page.locator('#debug-mode').check()
        page.locator('#canvas').click()
        page.keyboard.press(str(number), delay=80)
        page.wait_for_timeout(50)
        assert read()['s']['level'] == level and read()['s']['max_lives'] == lives
        while read()['s']['outcome'] == 'Playing':
            before = read()['s']['life']
            page.keyboard.down('Space')
            wait(f's.life > {before} || s.outcome == "Lost"')
            page.keyboard.up('Space')
            page.wait_for_timeout(50)
        wait('+d.gameOverOpacity == 1')
        failure = read()
        assert failure['s']['level'] == level and failure['s']['life'] == lives
        page.wait_for_timeout(1800)
        assert read() == failure
        page.locator('#stage').screenshot(path=str(out / f'game-over-room-{number}.png'))
        page.keyboard.down('Space')
        wait('s.life == 1 && s.outcome == "Playing"')
        page.wait_for_timeout(200)
        retried = read()
        assert retried['s']['level'] == level and retried['speed'] == 1
        assert retried['s']['history_lengths'] == [] and retried['opacity'] == 0
        page.keyboard.up('Space')
        page.reload()
        page.wait_for_function('document.querySelector("canvas").dataset.state')
        assert read()['s']['level'] == 0 and read()['s']['life'] == 1
        assert not read()['s']['inventory']['time_acceleration']
        assert not page.locator('#debug-mode').is_checked()
        results.append({'room': number, 'lives': lives, 'game_over_stays': True, 'retry_same_room': True, 'refresh_starts_fresh': True})
        print(f'Room {number}: Game Over, same-room retry and fresh unsaved reload passed.', flush=True)
    assert not errors, errors
    (out / 'retry-results.json').write_text(json.dumps({'passed': True, 'rooms': results, 'errors': errors}, indent=2))
    browser.close()
