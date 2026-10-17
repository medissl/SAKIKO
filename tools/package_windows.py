"""Validate and package the already-tested embedded Windows executable."""
from pathlib import Path
import hashlib
import json
import struct
import sys
import zipfile

root = Path(__file__).resolve().parents[1]
build = Path(sys.argv[2]).resolve() if len(sys.argv)>2 else root / "builds/windows"
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
exe = build / "SAKIKO.exe"
blob = exe.read_bytes()
assert blob[:2] == b"MZ"
offset = struct.unpack_from("<I", blob, 0x3C)[0]
assert blob[offset:offset+4] == b"PE\0\0" and struct.unpack_from("<H", blob, offset+4)[0] == 0x8664
assert blob[-4:] == b"GDPC", "Embedded game data is missing"
assert sha(Path(sys.argv[1])) == sha(exe), "Tested executable differs from packaged executable"
contents = {p.relative_to(build).as_posix(): sha(p) for p in sorted(build.rglob("*"))
            if p.is_file() and p.name != "SHA256SUMS.txt"}
(build/"SHA256SUMS.txt").write_text("".join(f"{digest}  {name}\n" for name,digest in contents.items()), encoding="utf-8")
archive = Path(sys.argv[3]).resolve() if len(sys.argv)>3 else root / "builds/SAKIKO-Windows-x64.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as out:
    for path in sorted(build.rglob("*")):
        if path.is_file(): out.write(path, "SAKIKO/"+path.relative_to(build).as_posix())
with zipfile.ZipFile(archive) as check:
    assert check.testzip() is None
    for entry in check.namelist():
        relative = entry.removeprefix("SAKIKO/")
        assert hashlib.sha256(check.read(entry)).hexdigest() == sha(build/relative)
        assert not any(part in relative.split("/") for part in ["tests","tools",".local-user",".asset-cache"])
        assert Path(relative).suffix.lower() not in [".gd",".gdc",".pdb",".wav",".tpz"]
    assert any("OFL" in name for name in check.namelist())
    assert "SAKIKO/licenses/GODOT_WINDOWS_EXPORT_NOTICES.txt" in check.namelist()
digest = sha(archive)
archive.with_suffix(".zip.sha256").write_text(digest+"  "+archive.name+"\n", encoding="utf-8")
report = {"archive":str(archive.relative_to(root)),"archive_bytes":archive.stat().st_size,
          "sha256":digest,"exe_bytes":len(blob),"exe_sha256":sha(exe),"files":len(contents)+1,
          "platform":"Windows x86_64; embedded PCK",
          "validation":"PE x64 header; embedded PCK footer; archive CRC; every file hash; tested isolated executable hash; required notices; no QA/tools/cache/audio-source payload",
          "contents":contents}
(Path(sys.argv[4]) if len(sys.argv)>4 else root/"tests/artifacts/release_package_validation.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps({key:report[key] for key in ["archive","archive_bytes","sha256","files"]}))
