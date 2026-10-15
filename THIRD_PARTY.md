# Third-party dependencies

- **Selene / Selene WebGPU 0.37.3** - Apache-2.0.
  [Source repository](https://github.com/moonbit-community/selene).
  Verified source commit: `16e4a933c05165c3d668a697e8532ab464e911a7`.
- **moonbit-community/js-ffi 0.4.3** - Apache-2.0.
  Pinned directly for compatibility with the current MoonBit `moon.mod` format.
- **moonbit-community/harfbuzz 0.1.0** - Apache-2.0, with additional third-party notices included in the package.
  [Source repository](https://github.com/moonbit-community/harfbuzz).
  The original package's LICENSE and NOTICE files are preserved in `.deps/harfbuzz/`.

HarfBuzz is a transitive dependency of Selene WebGPU through the moon_cosmic font stack. The pinned release still contains legacy configuration files and an `extend` field that conflicts with a reserved word in the current compiler.

`scripts/bootstrap.py` extracts the SHA-256-verified original package into this project's `.deps` directory and applies these compatibility changes:

1. Run `moon fmt` to migrate legacy JSON configuration to `moon.mod` / `moon.pkg`.
2. Rename the newly reserved identifier `extend` to `extend_mode` in two source files.
3. Migrate 17 string-container snapshot assertions from `inspect` to `debug_inspect`, preserving every original expected value.
4. Disable style warnings only for this legacy dependency. Its algorithms, font data, and expected test results remain unchanged.

Upstream package SHA-256:

```text
5913988c8efc7b26e173145d694e0d39da15d623240707d9d511f6d04d10807f
```

The global MoonBit installation, global dependency cache, and Selene source are not modified. See [DEPENDENCIES.txt](DEPENDENCIES.txt) for the resolved dependency versions. Dependency licenses remain with their source packages.

## Exit icon

`assets/exit.svg` uses **exit-run** from Pictogrammers / Material Design Icons, by **Simran**, licensed under Apache-2.0. Only the white fill and dimensions were adjusted; the original path is preserved.

- [Icon page](https://pictogrammers.com/library/mdi/icon/exit-run/)
- [Original SVG](https://github.com/Templarian/MaterialDesign/blob/master/svg/exit-run.svg)
