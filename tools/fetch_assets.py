"""Download public CC0 assets and an OFL CJK font. No credentials required."""
from pathlib import Path
import html
import json
import re
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
RECORDS = []

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "StaffForgeDemo/0.1"})
    with urllib.request.urlopen(req, timeout=45) as response:
        return response.read()

def save(url, relative, source, license_name):
    destination = ASSETS / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists():
        destination.write_bytes(get(url))
    RECORDS.append({"path": str(destination.relative_to(ROOT)).replace("\\", "/"),
                    "source": source, "license": license_name, "bytes": destination.stat().st_size})
    print(f"Downloaded {relative}: {destination.stat().st_size:,} bytes", flush=True)
    return destination

def kenney(slug):
    source = f"https://kenney.nl/assets/{slug}"
    page = get(source).decode("utf-8")
    links = re.findall(r'href=["\']([^"\']+\.zip(?:\?[^"\']*)?)["\']', page)
    candidates = [html.unescape(x) for x in links if "kenney" in x or x.startswith("/")]
    if not candidates:
        raise RuntimeError("No ZIP download link on official page")
    url = candidates[0]
    if url.startswith("/"):
        url = "https://kenney.nl" + url
    archive = save(url, f"downloads/{slug}.zip", source, "CC0-1.0")
    out = ASSETS / "kenney" / slug
    out.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as package:
        for entry in package.infolist():
            target = (out / entry.filename).resolve()
            if not target.is_relative_to(out.resolve()):
                raise RuntimeError("Unsafe archive path")
        package.extractall(out)

def polyhaven(slug, short_name):
    metadata = json.loads(get(f"https://api.polyhaven.com/files/{slug}"))
    for channel, local in [("diff", "diffuse"), ("nor_gl", "normal"), ("rough", "roughness")]:
        formats = metadata[channel]["1k"]
        entry = formats.get("jpg") or formats.get("png")
        if not entry:
            continue
        extension = ".png" if entry["url"].split("?")[0].endswith(".png") else ".jpg"
        save(entry["url"], f"textures/{short_name}_{local}{extension}",
             f"https://polyhaven.com/a/{slug}", "CC0-1.0")

def main():
    for slug in ["impact-sounds", "interface-sounds", "particle-pack", "modular-dungeon-kit", "furniture-kit"]:
        try:
            kenney(slug)
        except Exception as exc:
            print(f"Asset unavailable {slug}: {type(exc).__name__}: {exc}", flush=True)
    for slug, short_name in [("fine_grained_wood", "wood"), ("stone_tiles", "stone")]:
        try:
            polyhaven(slug, short_name)
        except Exception as exc:
            print(f"Texture unavailable {slug}: {type(exc).__name__}: {exc}", flush=True)
    try:
        source = "https://github.com/google/fonts/tree/main/ofl/notosanssc"
        save("https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf",
             "fonts/NotoSansSC.ttf", source, "SIL Open Font License 1.1")
        save("https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt",
             "fonts/OFL.txt", source, "SIL Open Font License 1.1")
    except Exception as exc:
        print(f"Font unavailable: {type(exc).__name__}: {exc}", flush=True)
    (ASSETS / "download-manifest.json").write_text(json.dumps(RECORDS, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Recorded {len(RECORDS)} downloads.", flush=True)

if __name__ == "__main__":
    main()
