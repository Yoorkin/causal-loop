# Causal Loop

A four-level causal puzzle demo built with MoonBit and Selene WebGPU. Each life records your inputs. The next life replays them, but changes to the shared world can change what your past self accomplishes.

The practice level starts with **one life** and introduces movement, two jumps, and dropping through a one-way platform with **S**. Touching the heart near the exit adds a life. Time flows normally here, too. Each loop charges for **18 seconds**, then releases a **0.2-second shockwave**. Only contact with the expanding shockwave freezes a character; the charging circle is harmless. Staying farther from its center gives you a little more time to act. Levels 2 and 3 each provide **two lives**; level 4 provides **three**. A completed shockwave or a fatal fall ends the current life. Running out of lives ends the attempt.

After collecting the time-acceleration item, hold **Space** to advance the whole world at **6x speed**. Acceleration stops at the start of a shockwave, a new life, or a level transition. Release and press Space again to reactivate it. Touching the exit automatically advances to the next level with a short horizontal reveal.

## Pickups and inventory

The acceleration item sits just before the exit in level 2. Either your current character or an active past self can collect it. Its icon flies along an arc into the upper-left inventory over 0.85 seconds, continuing across level transitions. The inventory displays owned items in thin square frames with a 14px **SPACE** label below the icon; empty slots are hidden.

Uncollected items and hearts bob along a sine wave, with cyan and red light shining upward from the ground respectively. Items remain available after death, retries, and level changes, but refreshing the page clears them. The **Debug** checkbox at the top-right of the page enables acceleration without collecting the item; it does not grant ownership. Active acceleration makes the clock tremble slightly. Releasing Space stops that effect, while the normal warning during the final four seconds still applies.

## Clock, lives, and rewind

Red hearts at the top show remaining lives. The central clock uses opaque inverted strokes for its ticks and hands. Each life starts on the hour assigned to its level: **12:00, 1:00, 2:00, or 3:00**. The hour hand advances alongside the minute hand at the same ratio as a real clock.

The harmless charging circle inverts the scene over the clock and grows from radius zero to the inner edge of the ticks at 34 pixels. During the last four seconds, the clock and circle tremble with increasing intensity. The circle then becomes a solid, nearly black purple shockwave that launches immediately, accelerates outward, and stops when it fills the scene. Characters remain in front of it and freeze in their current poses when touched.

A normal life ending immediately consumes a heart. If another life remains, the full-screen wave holds for 0.6 seconds, then fades over 1.1 seconds as both hands rewind to the level's starting hour. The next life begins immediately afterward. Including the impact, this normally takes **1.9 seconds**.

The first life consumed in level 2 has a longer teaching sequence: its heart stays in the HUD for 0.2 seconds, flies to the clock over 0.8 seconds, blinks for 0.6 seconds, then disappears to trigger a **4-second rewind**. The hands pause at the starting hour for another 1.6 seconds before the next life begins. There is no separate respawn preparation stage. The clock trembles gently during the first two seconds of rewind and gradually settles. These transitions do not consume time from the next life.

When no lives remain, the final scene and hand positions stay frozen. There is no fade-out or rewind. **Game Over** and **space retry** fade in; a fresh press of Space restarts the current level.

## Running locally

You need the MoonBit toolchain, Python 3.9+, an internet connection for dependency setup, and a desktop browser with WebGPU support. Verified versions:

| Component | Version |
| --- | --- |
| moon | 0.1.20261012, commit 748b63c |
| moonc | v0.10.15+943464bfa |
| Selene / Selene WebGPU | 0.37.3 / 0.37.3 |
| js-ffi | 0.4.3 |
| Browser used for graphics validation | Chromium 145.0.7632.6 on macOS Apple Silicon |

From the project directory:

```sh
python3 scripts/bootstrap.py
moon build --release
python3 scripts/serve.py
```

Open [localhost:8000](http://127.0.0.1:8000). WebGPU requires a secure context; localhost works. Do not open the HTML file directly. If the port is occupied, use `python3 scripts/serve.py --port 8001`.

The bootstrap script downloads and verifies the legacy HarfBuzz transitive dependency, applies compatibility changes inside this project's `.deps` directory, then runs `moon update` and checks. The workspace references this local copy, so bootstrap is required on the first run. The global toolchain and dependency cache are not modified. See [DEPENDENCIES.txt](DEPENDENCIES.txt) and [THIRD_PARTY.md](THIRD_PARTY.md) for exact versions and patch details.

To create a static distribution:

```sh
python3 scripts/package.py
python3 scripts/serve.py --dist
```

The generated `dist/` directory can be served by an ordinary static server. Remote deployments require HTTPS.

## Controls

| Key | Action |
| --- | --- |
| A / D or Left / Right | Move |
| W | Jump; release before jumping again |
| S | Drop through the one-way platform beneath you; elsewhere, hold to crouch and move slowly. Stand on release when there is enough clearance. |
| Space, held | Advance the world at 6x after collecting the item or enabling Debug. The current character records neutral input. Release to return to 1x. |
| Backspace | Clear recorded history and restart the current level |
| Escape | Pause / resume |
| Space, newly pressed after failure | Clear history and retry the current level. Holding it through the retry does not immediately accelerate time. |
| Enter | Resume from pause |
| 1 / 2 / 3 / 4 | Debug level selection: practice / broken bridge / three gates / dual switches. Clears recorded history. |

Each life spawns at a slightly different position within an area roughly three characters wide, falling naturally from a random height 54-74 pixels above the ground. Replays preserve that life's original spawn position. Press W after landing to jump.

Pressure plates activate when stepped on. The current character is orange with a small marker overhead; past lives and characters frozen by the wave are gray-purple. The simple line figures breathe while idle and swing their arms and legs while walking. Their heads and feet indicate facing direction, which remains unchanged when they stop. Holding a movement key against an obstacle still plays the walking animation, including during replays.

Crouching reduces collision height from 38 to 24 pixels, slows movement to roughly one-quarter of normal speed, and halves the walking animation rate. Crouching characters can still activate plates, and past lives replay crouch inputs. When a recording ends, its character disappears and releases any plate. Leaving the window automatically pauses the game.

## Levels and solutions

1. **Practice:** Move right, jump up the two steps, and press S on the cyan dashed platform to drop through it. Continue right to collect the heart and reach the exit. The heart increases the life limit from one to two and can only be collected once per attempt; retrying restores it.
2. **Broken bridge:** During the first life, hold D for about six seconds, continuing even after the barrier stops you. Release D and wait for the next life; Debug mode allows Space to accelerate this wait. During the second life, move left onto the pressure plate. Your past self replays the same rightward input, crosses the bridge, collects the acceleration item, and reaches the exit.
3. **Stepped passage:** Three plates sit on platforms at different heights, with lines connecting them to their orange gates. The first two plates are outside the passage. The third sits on raised ground between the first and second gates. The passage requires climbing, dropping, and jumping onto another raised section; there is no broken bridge. Gates rise gradually while their plates are held and immediately begin descending when released, without a closing delay.
4. **Staggered switches:** Use the first life to stand on the left plate and wait for the next life. Use the second to stand on the middle plate and wait again. During the third, run right while both past selves hold their plates to open the exit route.

One reproducible solution for level 3: record continuous rightward movement in the first life, pressing W roughly 2 and 3.3 seconds after starting to move. Continue right until about 5.3 seconds, then accelerate to the next life. The first attempt remains blocked by the closed first gate. In the second life, land, jump left onto the lowest outside plate, and stay until roughly 1.5 seconds into the loop. Jump right onto the second platform and stop. Your past self can now pass the first gate, jump onto the third plate inside the passage, and clear the remaining raised section to reach the exit. Late plate activation changes where the recorded jumps occur. With only two lives, mistiming requires a retry. See [sim/tunnel_test.mbt](sim/tunnel_test.mbt) for the precise input sequence and a mistimed failure case.

Any active, unfrozen character can trigger the exit. Completing level 4 returns to the practice level. After Game Over, release and press Space again to retry, or use Backspace.

## Implementation and layout

```text
sim/          Pure MoonBit fixed-point physics, input history, shared mechanisms, 60 Hz simulation, and tests
game/         Selene App systems, ECS Transform projection, input handling, and scene rendering
web/          Official Selene WebGPU platform overrides and entry point
scripts/      Dependency setup, local server, packaging, and browser regression checks
artifacts/qa/ Generated browser screenshots and structured validation results
index.html    Minimal browser shell
moon.mod      Pinned dependency versions
moon.work     Workspace including the local compatibility copy of a legacy dependency
```

MoonBit owns game logic, timing, collisions, levels, and rendering commands. A small amount of JavaScript handles the browser shell, missing Selene keys, focus events, and read-only test snapshots. Selene draws the shockwave and characters in order; the browser applies local color inversion to already rendered pixels using clock paths and charge radius calculated by MoonBit. It does not duplicate the scene or run gameplay timers. Recordings contain no positions, scripted solutions, or teleportation.

## Validation

```sh
moon fmt
moon check
moon build
moon build --release
moon test
moon info
```

Simulation tests cover replay, changes to historical outcomes, synchronization, full-state equivalence at 1x and 6x, life transitions after impact, exhaustion of lives, shared mechanisms, world reconstruction, iteration-order independence, immutable recordings, expired replays, three independent gates, immediate gradual closure, anti-crush behavior, and stopping batches at death or impact boundaries.

The simulation and presentation math suites contain **57 tests**. They cover solutions for all four levels, practice and level 3 solutions across 64 spawn seeds, one-way platform passage and replay, one-time heart collection, the first-rewind teaching sequence, and failed solutions caused by incorrect timing. Browser checks use real keyboard input and rendered pixels. Results are written to `artifacts/qa/browser-results.json`; the initial setup log is stored locally at `artifacts/qa/clean-install.log`.

Browser regression checks additionally require Python Playwright and Chromium. These are test tools, not runtime dependencies. Keep the local server running, then execute:

```sh
python3 -m pip install playwright Pillow
python3 -m playwright install chromium
python3 scripts/qa_browser.py --headless
python3 scripts/qa_time_wave.py
python3 scripts/qa_tutorial.py
python3 scripts/qa_heart_rewind.py
python3 scripts/qa_retry.py
```

The scripts play through levels using real key events and only read MoonBit-published snapshots; they do not inject game state. Screenshots and structured results are generated under `artifacts/qa/`, which is excluded from version control.

## Known limitations

- Desktop keyboard and WebGPU are required. There are no touch controls or non-WebGPU rendering fallback.
- History and inventory exist only in memory. There is no save system; refreshing clears progress and items and returns to the practice level. Each recording contains at most 1,092 frames.
- Long frames have a capped catch-up interval. Simulation may run slower than wall-clock time, but recorded input frames are never skipped.
- Characters do not collide with one another. A descending gate in level 3 waits if its next position would overlap a character, then continues after the character moves away.
- The upstream transitive dependency `hackwaly/moonback@0.8.1` emits a deprecation warning. It does not prevent the verified build from running.

See [DESIGN.md](DESIGN.md) for architecture and determinism rules. That document is maintained in Chinese.
