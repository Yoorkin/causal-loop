"""Exercise wave contact, clock compositing and lifecycle using real keys only."""
import io
import json
import time
from pathlib import Path
from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright

out = Path(__file__).resolve().parents[1] / 'artifacts' / 'qa'
out.mkdir(parents=True, exist_ok=True)
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chromium', headless=True)
    page = browser.new_page(viewport={'width': 1280, 'height': 900}, device_scale_factor=1)
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.goto('http://127.0.0.1:8000/')
    page.wait_for_function('document.querySelector("canvas").dataset.state')
    page.locator('#debug-mode').check()

    def read():
        return page.evaluate('''() => {
          const d = document.querySelector('canvas').dataset;
          return {s: JSON.parse(d.state), phase:d.wavePhase, radius:+d.waveRadius,
            strength:+d.waveStrength, minute:+d.minuteDegrees, hour:+d.hourDegrees,
            tick:+d.simulationTick, mode:d.mode, speed:+d.speed, shakeX:+d.clockShakeX, shakeY:+d.clockShakeY,
            gameOverOpacity:+d.gameOverOpacity};
        }''')

    def wait(expr):
        page.wait_for_function('() => {const d=document.querySelector("canvas").dataset; const s=JSON.parse(d.state); return ' + expr + ';}', timeout=20000)

    def press(key):
        page.keyboard.press(key, delay=50)
        page.wait_for_timeout(30)

    def shot(name):
        data = page.locator('#stage').screenshot(path=str(out / (name + '.png')))
        return Image.open(io.BytesIO(data)).convert('RGB')

    def pause():
        if read()['mode'] != 'paused':
            page.keyboard.down('Escape')
            wait('d.mode == "paused"')
            page.keyboard.up('Escape')
            page.wait_for_timeout(50)

    def resume():
        if read()['mode'] == 'paused':
            page.keyboard.down('Escape')
            wait('d.mode != "paused"')
            page.keyboard.up('Escape')
            page.wait_for_timeout(50)

    def reset(level=1):
        press(str([1, 2, 4, 3][level]))
        assert read()['s']['level'] == level and read()['s']['life'] == 1

    # Both the opaque clock and the charging disc invert pixels, with the disc on top.
    reset()
    pause()
    base = shot('clock-start')
    resume()
    page.keyboard.down('Space')
    wait('s.tick >= 540')
    page.keyboard.up('Space')
    pause()
    middle = read()
    assert middle['phase'] == 'growing' and 19 <= middle['radius'] < 24
    assert abs(middle['hour'] - 30 - middle['minute'] / 12) < 1e-8
    charging = shot('clock-halfway')
    for point in [(570, 310), (550, 310)]:
        # No clock stroke at these points; invert the same scene.
        expected = [255-c for c in base.getpixel(point)]
        assert max(abs(a-b) for a,b in zip(charging.getpixel(point), expected)) <= 2, (point, charging.getpixel(point), expected)
    assert charging.getpixel((100, 100)) == base.getpixel((100, 100))
    assert page.locator('#loop-clock').evaluate('(e) => getComputedStyle(e).mixBlendMode') == 'difference'
    # Right cardinal tick sits outside the disc; compare against its plain backdrop.
    backdrop = charging.getpixel((598, 314))
    clock_pixel = charging.getpixel((598, 310))
    expected = [255-c for c in backdrop]
    assert max(abs(a-b) for a,b in zip(clock_pixel, expected)) <= 3, (clock_pixel, expected)
    page.wait_for_timeout(150)
    assert read() == middle
    print('Charging: full inversion, opaque inverse clock and hand movement passed.', flush=True)

    resume()
    page.keyboard.down('Space')
    wait('s.tick >= 900')
    page.keyboard.up('Space')
    pause()
    warning = read()
    assert 840 < warning['s']['tick'] < 960
    assert abs(warning['shakeX']) + abs(warning['shakeY']) > .1
    centers = page.evaluate("""() => ['loop-clock','charge-disc'].map(id=>{
      const r=document.getElementById(id).getBoundingClientRect();return [r.x+r.width/2,r.y+r.height/2];
    })""")
    assert max(abs(a-b) for a,b in zip(*centers)) < .1
    shot('clock-warning')
    page.wait_for_timeout(180)
    assert read() == warning
    print('Warning: clock and charging disc share the last-four-second shake; pause freezes it.', flush=True)

    # Record a near-centre history; current life stays farther away.
    reset()
    page.keyboard.down('d')
    wait('s.actors[0].x == 3920')
    page.keyboard.up('d')
    page.keyboard.down('Space')
    wait('s.life == 2')
    page.keyboard.up('Space')
    wait('s.actors[1].grounded')
    page.keyboard.down('Space')
    wait('s.tick >= 1080')
    r = read()
    assert r['s']['life'] == 2 and r['s']['actors'][1]['frozen_at'] == -1
    assert r['mode'] == 'play' and r['speed'] == 1
    page.keyboard.up('Space')
    # Move away while the wave advances; history freezes first.
    start_x = r['s']['actors'][1]['x']
    page.keyboard.down('a')
    wait('s.actors[0].frozen_at >= 0 && s.actors[1].frozen_at < 0')
    pause()
    page.keyboard.up('a')
    contact = read()
    assert contact['phase'] == 'expanding'
    assert contact['shakeX'] == 0 and contact['shakeY'] == 0
    assert contact['s']['actors'][1]['x'] < start_x
    near = contact['s']['actors'][0]
    elapsed = near['frozen_at'] - 1080
    radius_at_contact = (340 + 4270 * elapsed // 12 + 1830 * elapsed**3 // 12**3) / 10
    dx = max(0, 560 - (near['x'] + 240) / 10, near['x'] / 10 - 560)
    dy = max(0, 310 - (near['y'] + 380) / 10, near['y'] / 10 - 310)
    assert dx*dx + dy*dy <= radius_at_contact**2
    shot('clock-expanding')
    page.wait_for_timeout(180)
    assert read() == contact
    page.keyboard.down('a')
    resume()
    wait('s.actors[1].frozen_at >= 0')
    pause()
    page.keyboard.up('a')
    frozen = read()
    assert frozen['s']['actors'][0] == near
    assert frozen['s']['actors'][1]['frozen_at'] > near['frozen_at']
    shot('wave-contact-frozen')
    resume()
    wait('s.outcome == "Lost"')
    pause()
    held = read()
    assert held['radius'] == 644 and held['strength'] == 1 and held['phase'] == 'failed'
    full = shot('clock-covered')
    assert max(full.crop((515,265,605,355)).getextrema()[0]) > 220
    # Brightness stays low: no former full-screen inversion/white flash.
    assert max(ImageStat.Stat(full).mean) < 65
    for point in [(4,4), (1115,4), (4,615), (1115,615)]:
        assert max(full.getpixel(point)) < 70
    # The formerly visible floor edge is hidden, but frozen figures are above the wave.
    assert max(abs(a-b) for a,b in zip(full.getpixel((560,499)),full.getpixel((560,503)))) < 5
    for actor in held['s']['actors']:
        if actor['active']:
            crop = full.crop((actor['x']//10-4, actor['y']//10-8, actor['x']//10+28,actor['y']//10+40))
            assert sum(count for count,rgb in crop.getcolors(crop.width*crop.height) if min(rgb)>70) > 20
    page.wait_for_timeout(160)
    assert read() == held
    resume()
    wait('+d.gameOverOpacity > .2 && +d.gameOverOpacity < .8')
    pause()
    appearing = read()
    assert appearing['strength'] == 1 and appearing['minute'] == 360 and appearing['hour'] == 60
    shot('game-over-fading-in')
    resume()
    wait('+d.gameOverOpacity == 1')
    game_over = read()
    page.wait_for_timeout(2600)
    assert read() == game_over
    full_text = shot('game-over')
    for box in [(400,370,720,435), (480,438,640,468)]:
        crop = full_text.crop(box)
        assert sum(count for count,rgb in crop.getcolors(crop.width*crop.height) if min(rgb)>100) > 50
    for x in [544, 576]:
        assert full_text.getpixel((x,41)) == (52,66,75)
    press('Enter')
    assert read()['s']['outcome'] == 'Lost'
    page.keyboard.down('Space')
    wait('s.life == 1 && s.outcome == "Playing"')
    retry_tick = read()['tick']
    page.wait_for_timeout(350)
    assert read()['speed'] == 1 and 10 <= read()['tick'] - retry_tick <= 35
    assert read()['s']['history_lengths'] == [] and read()['gameOverOpacity'] == 0
    page.keyboard.up('Space')
    print('Failure: frozen impact and clock, fading Game Over text, empty hearts, Space retry passed.', flush=True)

    # Next life stays at tick 0 through hold/fade and a visible clock-zero pause.
    reset()
    page.keyboard.down('Space')
    wait('d.wavePhase == "holding"')
    assert read()['tick'] == 0
    held_start = time.monotonic()
    page.wait_for_timeout(250)
    assert read()['phase'] == 'holding'
    wait('d.wavePhase == "fading"')
    assert time.monotonic() - held_start >= 1.5
    assert read()['tick'] == 0
    wait('+d.waveStrength < .8')
    pause()
    fading = read()
    assert .3 < fading['strength'] < .8
    assert abs(fading['minute'] - 360 * fading['strength']) < 1e-7
    assert abs(fading['hour'] - 30 - 30 * fading['strength']) < 1e-7
    shot('clock-fading-backward')
    resume()
    wait('d.wavePhase == "growing" && s.life == 2 && s.tick > 0')
    reborn = read()
    assert reborn['mode'] == 'play' and reborn['speed'] == 1
    assert reborn['tick'] < 6
    shot('clock-immediate-rebirth')
    tick = read()['tick']
    page.wait_for_timeout(350)
    assert read()['speed'] == 1 and 10 <= read()['tick'] - tick <= 35
    page.keyboard.up('Space')
    pause()
    shot('clock-next-life')
    resume()
    page.keyboard.down('Space')
    wait('s.outcome == "Lost" && +d.gameOverOpacity == 1')
    page.wait_for_timeout(2600)
    assert read()['s']['outcome'] == 'Lost' and read()['minute'] == 360
    page.keyboard.down('Space')  # Repeated keydown cannot dismiss failure.
    page.wait_for_timeout(100)
    assert read()['s']['outcome'] == 'Lost'
    page.keyboard.up('Space')
    # Selene samples keyboard edges once per frame; let it observe release.
    page.wait_for_timeout(50)
    press('Space')
    assert read()['s']['life'] == 1 and read()['s']['outcome'] == 'Playing'
    print('Lifecycle: other lives still rewind; held Space cannot skip Game Over or accelerate retry.', flush=True)
    for level in [2,3]:
        reset(level)
        pause()
        r = read()
        assert abs(r['hour'] - ([0, 30, 90, 60][level] + r['minute']/12)) < 1e-7
        shot('clock-level-' + str(level))

    # Capture actual frame timing, including the 0.2-second impact and clock-zero pause.
    reset(2)
    page.keyboard.down('Space')
    frames, times, phases = [], [], []
    while True:
        r = read()
        if r['s']['life'] == 2 and r['phase'] == 'growing':
            break
        if r['s']['tick'] >= 820 and r['speed'] == 6:
            page.keyboard.up('Space')
        frames.append(Image.open(io.BytesIO(page.locator('#stage').screenshot())).convert('RGB').resize((840,465)))
        times.append(time.monotonic())
        phases.append(r['phase'])
        if len(frames) > 200:
            raise AssertionError('wave capture did not finish')
        page.wait_for_timeout(30)
    page.keyboard.up('Space')
    frames.append(Image.open(io.BytesIO(page.locator('#stage').screenshot())).convert('RGB').resize((840,465)))
    times.append(time.monotonic())
    durations = [max(10, round((b-a)*100)*10) for a,b in zip(times,times[1:])] + [500]
    frames[0].save(out/'time-wave.gif', save_all=True, append_images=frames[1:], duration=durations, loop=0)
    assert all(phase in phases for phase in ['growing','expanding','holding','fading'])
    assert not errors, errors
    results = {'passed':True, 'tests': ['last four seconds synchronized clock shake', 'inverse charge above clock', 'opaque inverse clock', 'no freeze before sweep', 'individual contact freeze', 'movement past 18 seconds', '0.2 second accelerating impact', '6x cancels at sweep', 'uniform opaque purple-black with actors in front', 'hold then fade on non-final lives', 'reverse both hands on non-final lives', 'new life frozen during presentation', 'immediate rebirth after clock-zero pause', 'held Space cannot rearm', 'Game Over holds scene and clock indefinitely', 'Game Over text fades in', 'Space retries with cleared histories at 1x', 'held Space cannot dismiss Game Over'], 'contact_ticks': [near['frozen_at'], frozen['s']['actors'][1]['frozen_at']], 'errors':errors, 'browser':browser.version}
    (out/'time-wave-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
    print(json.dumps(results, ensure_ascii=False), flush=True)
    browser.close()
