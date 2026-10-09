"""Package the standalone demo and editable project; standard library only."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "delivery"
OUT.mkdir(exist_ok=True)
(OUT / ".gdignore").touch()


def pack(name, files, prefix):
    target = OUT / name
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path, relative in sorted(files, key=lambda pair: str(pair[1])):
            archive.write(path, str(Path(prefix) / relative))
    with zipfile.ZipFile(target) as archive:
        bad = archive.testzip()
        if bad:
            raise RuntimeError(f"CRC failure: {bad}")
        count = len(archive.infolist())
    return {
        "name": name,
        "bytes": target.stat().st_size,
        "files": count,
        "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "crc_verified": True,
    }


windows = ROOT / "build/windows"
game_files = [
    (path, path.relative_to(windows))
    for path in windows.rglob("*")
    if path.is_file()
    and "smoke-save" not in path.parts
    and not path.name.endswith("-layout.json")
    and path.suffix != ".import"
]
if not (windows / "StaffForge.exe").exists() or not (windows / "StaffForge.pck").exists():
    raise RuntimeError("Build Windows release before packaging.")

source_files = []
for filename in ["project.godot", "main.tscn", "export_presets.cfg", "README.md", "README.en.md", "SECURITY.md", "SECURITY.zh-CN.md", ".gitignore"]:
    source_files.append((ROOT / filename, Path(filename)))
for folder in ["scripts", "data", "tests", "docs"]:
    for path in (ROOT / folder).rglob("*"):
        if path.is_file():
            source_files.append((path, path.relative_to(ROOT)))
for path in (ROOT / "assets").rglob("*"):
    if path.is_file() and not {"kenney", "downloads"}.intersection(path.relative_to(ROOT).parts):
        source_files.append((path, path.relative_to(ROOT)))
for filename in ["build.ps1", "fetch_assets.py", "prepare_assets.py", "package.py", ".gdignore"]:
    path = ROOT / "tools" / filename
    if path.is_file():
        source_files.append((path, path.relative_to(ROOT)))

reports = [
    pack("StaffForge-Windows-x64.zip", game_files, "StaffForge"),
    pack("StaffForge-Godot-Project.zip", source_files, "StaffForge-Project"),
]
(OUT / "packages.json").write_text(json.dumps(reports, ensure_ascii=False, indent=2), encoding="utf-8")
for report in reports:
    print(f"{report['name']}: {report['bytes'] / 1024 ** 2:.1f} MiB, {report['files']} files, CRC OK")
