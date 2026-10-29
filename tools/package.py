"""Create a player-ready ZIP with the expected top-level MoveAnything folder."""
from pathlib import Path
import hashlib, zipfile

ROOT=Path(__file__).resolve().parents[1]
output=ROOT/'dist';output.mkdir(exist_ok=True)
target=output/'MoveAnything.zip'
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
    for file in sorted((ROOT/'MoveAnything').rglob('*')):
        if file.is_file():archive.write(file,file.relative_to(ROOT).as_posix())
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
    assert 'MoveAnything/MoveAnything.toc' in archive.namelist()
digest=hashlib.sha256(target.read_bytes()).hexdigest()
target.with_suffix('.zip.sha256').write_text(digest+'  '+target.name+'\n',encoding='ascii')
print('Created dist/MoveAnything.zip and its SHA-256 file')
