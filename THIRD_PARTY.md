# 第三方依赖

- Selene / Selene WebGPU 0.37.3，Apache-2.0。
  https://github.com/moonbit-community/selene
  源码核对提交：`16e4a933c05165c3d668a697e8532ab464e911a7`。
- moonbit-community/js-ffi 0.4.3，Apache-2.0。
  直接约束版本以兼容当前 MoonBit 的 `moon.mod` 格式。
- moonbit-community/harfbuzz 0.1.0，Apache-2.0；包内另附第三方 NOTICE。
  https://github.com/moonbit-community/harfbuzz
  原始发布包的 LICENSE、NOTICE 保留于 `.deps/harfbuzz/`。

HarfBuzz 是 Selene WebGPU 的 moon_cosmic 字体链的间接依赖。其当前发布包仍含旧配置和 `extend` 字段。
`scripts/bootstrap.py` 在本项目 `.deps` 中解压经 SHA-256 核验的原始包，并执行以下兼容处理：

1. `moon fmt` 将旧 JSON 配置迁移为 `moon.mod` / `moon.pkg`。
2. 在两个源码文件中将新增保留字 `extend` 重命名为 `extend_mode`。
3. 17 个字符串容器快照断言从 `inspect` 迁移为 `debug_inspect`，保留全部原始期望值。
4. 仅为该旧依赖屏蔽风格警告；不修改其算法、字体数据或测试期望。

上游发布包 SHA-256：
`5913988c8efc7b26e173145d694e0d39da15d623240707d9d511f6d04d10807f`

没有修改全局 MoonBit 安装或全局依赖缓存，没有修改 Selene 源码。
完整的实际依赖版本见 `DEPENDENCIES.txt`；各依赖的许可证随其源码包保留。

出口图标 `assets/exit.svg` 来自 Pictogrammers / Material Design Icons 的 `exit-run`（作者 Simran），Apache-2.0。仅调整白色填充和尺寸，保留原始路径。
https://pictogrammers.com/library/mdi/icon/exit-run/
https://github.com/Templarian/MaterialDesign/blob/master/svg/exit-run.svg
