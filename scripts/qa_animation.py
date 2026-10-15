"""Check rendered walking/idle animation and facing using real keyboard input."""
import io
import json
from pathlib import Path
from PIL import Image
from playwright.sync_api import sync_playwright

output = Path(__file__).resolve().parents[1] / 'artifacts' / 'qa'
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chromium', headless=True)
    page = browser.new_page(viewport={'width': 1280, 'height': 900}, device_scale_factor=2)
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.goto('http://127.0.0.1:8000/')
    page.wait_for_function('document.querySelector("canvas").dataset.state')
    canvas = page.locator('canvas')
    box = canvas.bounding_box()
    clip = {'x': box['x'] + 260, 'y': box['y'] + 430, 'width': 190, 'height': 90}

    def state():
        return page.evaluate('JSON.parse(document.querySelector("canvas").dataset.state)')

    def wait(expression):
        page.wait_for_function('() => { const s = JSON.parse(document.querySelector("canvas").dataset.state); return ' + expression + '; }')

    frames = []
    def capture(count, name):
        states = []
        for i in range(count):
            s = state()
            states.append(s)
            raw = page.screenshot(clip=clip)
            frames.append(Image.open(io.BytesIO(raw)).convert('RGB'))
            if i == count // 2:
                (output / (name + '.png')).write_bytes(raw)
            wait(f's.tick >= {s["tick"] + 6}')
        return states

    page.keyboard.press('2', delay=80)
    page.wait_for_timeout(50)
    page.keyboard.down('d')
    wait('s.actors[0].x == 3920 && s.actors[0].grounded')
    start = len(frames)
    blocked = capture(20, 'actor-blocked-walking')
    assert all(s['actors'][0]['x'] == 3920 and s['actors'][0]['walking'] and s['actors'][0]['facing'] == 1 for s in blocked)
    assert len({s['actors'][0]['stride'] for s in blocked}) > 4
    assert len({im.tobytes() for im in frames[start:]}) > 4

    page.keyboard.up('d')
    wait('!s.actors[0].walking')
    start = len(frames)
    idle = capture(12, 'actor-idle-right')
    assert all(s['actors'][0]['facing'] == 1 for s in idle)
    assert len({im.tobytes() for im in frames[start:]}) > 2

    page.keyboard.down('a')
    wait('s.actors[0].facing == -1 && s.actors[0].walking')
    capture(5, 'actor-walking-left')
    page.keyboard.up('a')
    wait('!s.actors[0].walking')
    left = capture(12, 'actor-idle-left')
    assert all(s['actors'][0]['facing'] == -1 for s in left)
    assert len({s['actors'][0]['x'] for s in left}) == 1
    # Check the body itself, excluding its overhead marker: a mirrored image
    # must remain over the collision body, not just preserve facing in state.
    pixels = Image.open(output / 'actor-idle-left.png').convert('RGB')
    body_top = int((left[0]['actors'][0]['y'] / 10 - 430) * 2)
    colored_xs = [x for y in range(body_top, pixels.height) for x in range(pixels.width)
                  if (lambda c: c[1] > 125 and c[2] > 125 and c[1] > c[0] * 1.5)(pixels.getpixel((x, y)))]
    assert len(colored_xs) > 200, 'The left-facing sprite is missing from its collision body'
    origin_x = left[0]['actors'][0]['x'] / 10 - 260
    assert min(colored_xs) >= (origin_x - 2) * 2
    assert max(colored_xs) <= (origin_x + 26) * 2

    standing_y = state()['actors'][0]['y']
    page.keyboard.down('s')
    wait('s.actors[0].crouching && s.actors[0].grounded')
    crouched = capture(8, 'actor-crouched')
    assert all(s['actors'][0]['y'] == standing_y + 140 for s in crouched)
    page.keyboard.down('d')
    wait('s.actors[0].walking && s.actors[0].facing == 1')
    crawling = capture(4, 'actor-crouch-walking')
    assert all(s['actors'][0]['crouching'] for s in crawling)
    for before, after in zip(crawling, crawling[1:]):
        assert after['actors'][0]['x'] - before['actors'][0]['x'] == (after['tick'] - before['tick']) * 8
    page.keyboard.up('d')
    page.keyboard.up('s')
    wait('!s.actors[0].crouching && !s.actors[0].walking')
    assert state()['actors'][0]['y'] == standing_y
    capture(6, 'actor-standing-restored')

    crouch_pixels = Image.open(output / 'actor-crouched.png').convert('RGB')
    body_pixels = [(x, y) for y in range(int((standing_y / 10 - 430 + 14) * 2), crouch_pixels.height)
                   for x in range(crouch_pixels.width)
                   if (lambda c: c[1] > 125 and c[2] > 125 and c[1] > c[0] * 1.5)(crouch_pixels.getpixel((x, y)))]
    assert len(body_pixels) > 150, 'Crouch sprite must be visible at the shortened collision body'
    assert max(y for x, y in body_pixels) - min(y for x, y in body_pixels) >= 40
    canvas.screenshot(path=str(output / 'line-characters-scene.png'))
    frames[0].save(output / 'actor-animations.gif', save_all=True, append_images=frames[1:], duration=100, loop=0, disposal=2)

    page.keyboard.down('Escape')
    page.wait_for_function('document.querySelector("canvas").dataset.mode === "paused"')
    page.keyboard.up('Escape')
    frozen = state()
    pixels = page.screenshot(clip=clip)
    page.wait_for_timeout(250)
    assert state() == frozen and page.screenshot(clip=clip) == pixels
    assert not errors, errors
    result = {'passed': True, 'blocked_gait_changes_in_pixels': True, 'idle_animation_changes_in_pixels': True, 'facing_retained_after_release': True, 's_crouches_and_releases': True, 'crouch_speed_pixels_per_second': 48, 'pause_freezes_pose': True, 'errors': errors}
    (output / 'animation-results.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result))
    browser.close()
