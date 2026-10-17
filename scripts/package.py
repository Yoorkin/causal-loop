#!/usr/bin/env python3
"""Create a self-contained static WebGPU distribution. No upload/publishing."""
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
subprocess.run(['moon', 'build', 'web', '--release'], cwd=root, check=True)
dist = root / 'dist'
dist.mkdir(exist_ok=True)
source = root / '_build/js/release/build/yorkin/causal_loop/web/web.js'
shutil.copy2(source, dist / 'game.js')
shutil.copytree(root / 'assets', dist / 'assets', dirs_exist_ok=True)
html = (root / 'index.html').read_text().replace('_build/js/release/build/yorkin/causal_loop/web/web.js', 'game.js')
(dist / 'index.html').write_text(html)
(dist / '.nojekyll').touch()
shutil.copy2(root / 'THIRD_PARTY.md', dist / 'THIRD_PARTY.md')
shutil.copy2(root / 'DEPENDENCIES.txt', dist / 'DEPENDENCIES.txt')
shutil.copy2(root / 'LICENSE', dist / 'LICENSE')
for dependency_root in [root / '.mooncakes', root / '.deps']:
    for source in dependency_root.rglob('*'):
        if source.is_file() and source.name.startswith(('LICENSE', 'NOTICE')):
            target = dist / 'licenses' / source.relative_to(dependency_root)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
print('Static build ready: python3 scripts/serve.py --dist')
