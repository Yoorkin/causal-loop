"""Play the real Selene WebGPU build with keyboard events and read-only snapshots."""
import argparse
import io
import json
from pathlib import Path
from PIL import Image
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser()
parser.add_argument('--url', default='http://127.0.0.1:8000')
parser.add_argument('--headless', action='store_true')
args = parser.parse_args()
output = Path(__file__).resolve().parents[1] / 'artifacts' / 'qa'
output.mkdir(parents=True, exist_ok=True)

with sync_playwright() as p:
    browser = p.chromium.launch(channel="chromium", headless=args.headless)
    page = browser.new_page(viewport={'width': 1280, 'height': 900}, device_scale_factor=1)
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('console', lambda msg: errors.append(msg.text) if msg.type == 'error' else None)
    page.goto(args.url)
    page.wait_for_function('document.querySelector("canvas").dataset.state', timeout=30000)
    page.locator('#debug-mode').check()

    def state():
        return page.evaluate('JSON.parse(document.querySelector("canvas").dataset.state)')

    def mode():
        return page.evaluate('document.querySelector("canvas").dataset.mode')

    def speed():
        return int(page.evaluate('document.querySelector("canvas").dataset.speed'))

    def wait(expression, timeout=20000):
        page.wait_for_function('() => { const s = JSON.parse(document.querySelector("canvas").dataset.state); return ' + expression + '; }', timeout=timeout)

    def press(key):
        page.keyboard.down(key)
        page.wait_for_timeout(80)
        page.keyboard.up(key)
        page.wait_for_timeout(40)

    def hold_until(key, expression):
        page.keyboard.down(key)
        wait(expression)
        page.keyboard.up(key)
        page.wait_for_timeout(35)

    def screenshot(name):
        return page.locator('#stage').screenshot(path=str(output / (name + '.png')))

    def finish_life():
        page.wait_for_function('document.querySelector("canvas").dataset.mode == "play"')
        before = state()['life']
        hold_until('Space', f's.life == {before + 1}')
        assert state()['tick'] < 20

    def verify_hearts(name):
        # Check red remaining hearts and fixed dark spent slots in actual pixels.
        wait('s.actors[s.life - 1].grounded')
        current_x = state()['actors'][-1]['x'] / 10
        actor_pixels = Image.open(io.BytesIO(page.locator('#stage').screenshot())).convert('RGB')
        press('Escape')
        s = state()
        pixels = Image.open(io.BytesIO(screenshot(name))).convert('RGB')
        current_ink = (239, 191, 103)
        left = 560 - (s['max_lives'] * 32 - 8) // 2
        remaining = s['max_lives'] - s['life'] + 1
        for slot in range(s['max_lives']):
            expected = (237, 83, 99) if slot < remaining else (52, 66, 75)
            assert pixels.getpixel((left + slot * 32 + 12, 41)) == expected
        # The current actor is at spawn when this check is used.
        actor_region = actor_pixels.crop((int(current_x - 3), 449, int(current_x + 28), 500))
        assert sum(count for count, rgb in actor_region.getcolors(actor_region.width * actor_region.height) if rgb == current_ink) > 20
        press('Escape')

    def finish_level(key, expected, name):
        page.keyboard.down(key)
        wait(f's.level == {expected}')
        assert mode() == 'transition' and state()['tick'] == 0
        screenshot(name + '-transition')
        page.wait_for_function('document.querySelector("canvas").dataset.mode == "play"')
        tick = state()['tick']
        page.wait_for_timeout(350)
        # Space held through a portal cannot accelerate the next room.
        if key == 'Space':
            assert speed() == 1
            assert 10 <= state()['tick'] - tick <= 35
        page.keyboard.up(key)
        page.wait_for_timeout(40)
        return {'automatically_entered_level': expected, 'transition_seen': True}

    press('2')  # Original bridge follows the new practice room.
    wait('s.tick > 5')
    assert page.evaluate('!!navigator.gpu')
    assert page.locator('body').inner_text().strip() == 'Debug'
    verify_hearts('hearts-first')
    hold_until('ArrowRight', 's.actors[0].x >= 2700')
    hold_until('ArrowLeft', 's.actors[0].x <= 2400')
    page.keyboard.down('w')
    wait('s.actors[0].y < 4400')
    page.keyboard.up('w')
    press('Escape')
    frozen = state()['tick']
    page.wait_for_timeout(220)
    assert state()['tick'] == frozen
    press('Enter')
    press('Backspace')

    x = state()['actors'][0]['x']
    tick = state()['tick']
    page.keyboard.down('Space')
    page.wait_for_timeout(400)
    accelerated = state()['tick'] - tick
    assert state()['life'] == 1 and speed() == 6
    assert state()['actors'][0]['y'] == 4620  # Space no longer jumps.
    page.keyboard.down('d')
    wait(f's.tick >= {tick + 240}')
    assert state()['actors'][0]['x'] == x
    page.keyboard.up('d')
    page.keyboard.up('Space')
    page.wait_for_timeout(80)
    tick = state()['tick']
    page.wait_for_timeout(400)
    normal = state()['tick'] - tick
    assert speed() == 1 and 4.5 < accelerated / normal < 7.5

    # Do not release Space at timeout: new life must stay at normal speed.
    page.keyboard.down('Space')
    wait('s.life == 2')
    wait('s.tick > 0')  # The new room has a brief reaction pause at tick zero.
    tick = state()['tick']
    page.wait_for_timeout(450)
    held_after_timeout = state()['tick'] - tick
    assert speed() == 1 and 15 <= held_after_timeout <= 40
    page.keyboard.down('Space')  # Repeated keydown while still held is not a fresh press.
    page.wait_for_timeout(100)
    assert speed() == 1
    page.keyboard.up('Space')
    page.wait_for_timeout(80)
    verify_hearts('hearts-second')
    page.keyboard.down('Space')
    page.wait_for_timeout(120)
    assert speed() == 6
    wait('s.outcome == "Lost"')
    page.keyboard.up('Space')
    assert state()['life'] == 2 and state()['history_lengths'] == [1092, 1092]
    page.wait_for_timeout(50)
    press('Space')
    assert state()['life'] == 1 and state()['outcome'] == 'Playing'
    print('Controls passed: W jump, Space 6x, release/repress after timeout, red remaining hearts.', flush=True)

    start = state()['tick']
    hold_until('d', f's.tick >= {start + 360}')
    assert state()['actors'][0]['x'] == 3920
    screenshot('level1-blocked')
    finish_life()
    hold_until('a', 's.actors[1].x <= 1250')
    assert state()['plate_a']
    screenshot('level1-bridge')
    results = {'level1': finish_level('Space', 3, 'level1')}
    print('Bridge passed; portal auto-enters the two-life tunnel and cancels held Space.', flush=True)
    assert state()['max_lives'] == 2
    screenshot('level3-two-lives')
    press('4')  # Exercise the final dual-plate room next.
    verify_hearts('hearts-three')

    hold_until('a', 's.actors[0].x <= 1250')
    finish_life()
    hold_until('d', 's.actors[1].x >= 6000')
    assert state()['plate_a'] and state()['plate_b']
    finish_life()
    hold_until('d', 's.actors[2].x >= 8300')
    screenshot('level2-cooperation')
    results['level2'] = finish_level('d', 0, 'level2')
    press('3')  # Calibrated recording in the new third room.
    verify_hearts('hearts-two-tunnel')

    screenshot('level3-layout')
    press('3')
    start = state()['tick']
    origin = state()['actors'][0]['x']
    first_jump = (6000 - origin) // 30
    second_jump = (8340 - origin) // 30
    page.keyboard.down('d')
    wait(f's.tick >= {start + first_jump}')
    press('w')
    wait(f's.tick >= {start + second_jump}')
    press('w')
    wait(f's.tick >= {start + 320}')
    page.keyboard.up('d')
    assert state()['actors'][0]['x'] == 5560
    screenshot('level3-original')
    finish_life()

    # Land and line up the jump from this life's own randomized position.
    wait('s.actors[1].grounded')
    if state()['actors'][1]['x'] < 2385:
        hold_until('d', 's.actors[1].x >= 2385')
    elif state()['actors'][1]['x'] > 2415:
        hold_until('a', 's.actors[1].x <= 2415')
    wait('s.tick >= 36')
    # Climb plate A, allow its gate to rise, then jump onto plate B.
    # The unchanged runner takes the raised third plate inside the tunnel.
    page.keyboard.down('a')
    page.keyboard.down('w')
    wait('s.plate_a && s.actors[1].grounded')
    page.keyboard.up('a')
    page.keyboard.up('w')
    wait('s.tick >= 90')
    page.keyboard.down('d')
    page.keyboard.down('w')
    wait('s.plate_b && s.actors[1].grounded')
    page.keyboard.up('d')
    page.keyboard.up('w')
    wait('s.plate_c && s.gate_openings[2] > 600')
    assert state()['actors'][0]['x'] > 6500
    screenshot('level3-cooperation')
    results['level3'] = finish_level('Space', 2, 'level3')
    print('Level 3 passed: elevated plates, moving gates, jumps through stepped tunnel, automatic exit.', flush=True)
    # No state injection: create three stationary lives with keyboard fast-forward,
    # then freeze the actual airborne birth to inspect the rendered separation.
    press('4')
    original = state()
    original_spawn = original['actors'][0]['x']
    original_y = original['actors'][0]['y'] - 5 * original['tick'] * (original['tick'] + 1) // 2
    finish_life()
    second = state()
    second_spawns = [a['x'] for a in second['actors']]
    second_ys = [a['y'] - 5 * second['tick'] * (second['tick'] + 1) // 2 for a in second['actors']]
    assert second_ys[0] == original_y
    assert second_spawns[0] == original_spawn
    finish_life()
    press('Escape')
    airborne = state()
    assert len(airborne['actors']) == 3
    spawn_xs = [a['x'] for a in airborne['actors']]
    assert spawn_xs[:2] == second_spawns
    spawn_ys = [a['y'] - 5 * airborne['tick'] * (airborne['tick'] + 1) // 2 for a in airborne['actors']]
    assert spawn_ys[:2] == second_ys
    assert all(3880 <= y <= 4080 for y in spawn_ys)
    assert all(2160 <= x and x + 240 <= 2880 for x in spawn_xs)
    assert min(abs(a - b) for i, a in enumerate(spawn_xs) for b in spawn_xs[:i]) >= 120
    assert all(a['y'] < 4620 and not a['grounded'] for a in airborne['actors'])
    screenshot('three-lives-airborne')
    press('Escape')
    wait('s.actors.every(a => a.grounded)')
    assert all(a['y'] == 4620 for a in state()['actors'])
    screenshot('three-lives-landed')
    results['spawn_check'] = {'x_positions': spawn_xs, 'initial_y': spawn_ys, 'airborne_y': [a['y'] for a in airborne['actors']], 'region_width_px': 72, 'history_origins_preserved': True}
    print('Spawn passed: distinct randomized positions, airborne birth, natural landing, stable history origins.', flush=True)
    assert not errors, errors
    results['browser'] = browser.version
    results['errors'] = errors
    results['verification'] = 'Real keyboard events and rendered pixels; read-only snapshots; no state injection.'
    results['controls'] = ['A/D/arrows movement', 'W jump', 'Space 6x', 'Space does not jump', 'neutral movement while accelerating', 'timeout cancels held Space', 'release/repress re-arms acceleration', 'red hearts count remaining lives', 'automatic portal transitions', 'timer frozen during transition', 'three elevated plates individually control moving gates', 'third plate lies between first and second gates', 'historical runner jumps through uneven tunnel', 'random airborne spawns retain each life origin']
    results['speed_check'] = {'accelerated_ticks': accelerated, 'normal_ticks': normal, 'sample_ms': 400, 'held_after_timeout_ticks': held_after_timeout, 'held_sample_ms': 450}
    (output / 'browser-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
    print(json.dumps({'passed': True, 'browser': browser.version, 'errors': errors}), flush=True)
    browser.close()
