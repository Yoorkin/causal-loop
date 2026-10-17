# Game Demo

A six-room puzzle prototype built with MoonBit and Selene. Record your actions, rewind, and cooperate with your past lives.

[Play in your browser](https://yoorkin.github.io/causal-loop/)

Requires a desktop keyboard and a WebGPU-capable browser. Progress is kept in memory and resets when the page reloads.

## Run locally

Install the MoonBit toolchain and Python 3.9+, then run:

```sh
python3 scripts/bootstrap.py
python3 scripts/package.py
python3 scripts/serve.py --dist
```

Open [localhost:8000](http://127.0.0.1:8000). The `dist/` folder is also ready for static hosting over HTTPS.

## Controls

| Key | Action |
| --- | --- |
| A / D or Left / Right | Move |
| W | Jump |
| S | Crouch / drop through one-way platforms |
| Space | Hold to accelerate time after collecting the item; press to retry after Game Over |
| Escape | Pause / resume |
| Backspace | Restart the current room |
| 1–6 | Select a room for debugging |

The **Debug** checkbox loads the expected checkpoint for the current room and enables acceleration.

## Development

```sh
moon check
moon test
```

See [DESIGN.md](DESIGN.md) for design notes and [THIRD_PARTY.md](THIRD_PARTY.md) for dependency licenses.
