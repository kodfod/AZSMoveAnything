"""Rebuild renamed Noto font derivatives offline. Requires fonttools.
Normal addon use and translation edits do not require the original font files.
See docs/CONTRIBUTING.md for the four upstream input filenames and licenses.
"""
from pathlib import Path
import argparse,json
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT=Path(__file__).resolve().parents[1]
SOURCES={'.ttf':'NotoSans-Regular.ttf','-zh.otf':'NotoSansCJKsc-Regular.otf',
         '-ja.otf':'NotoSansCJKjp-Regular.otf','-ko.otf':'NotoSansCJKkr-Regular.otf'}

def required_text():
    text=''.join(chr(i) for i in range(32,127))
    for file in (ROOT/'locales').glob('*.json'):
        data=json.loads(file.read_text(encoding='utf-8'))
        for key,value in data.items():
            text+=key
            text+=(''.join(value.values()) if isinstance(value,dict) else value)
    text+='EnglishPolskiČeštinaDeutschPortuguês (Brasil)EspañolFrançaisRomânăTürkçeРусскийУкраїнська简体中文日本語한국어'
    return text

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font-dir',required=True,type=Path)
    args=parser.parse_args()
    output=ROOT/'MoveAnything/media';output.mkdir(exist_ok=True)
    text=required_text()
    for suffix,filename in SOURCES.items():
        font=TTFont(args.font_dir/filename)
        if suffix!='.ttf':
            options=subset.Options();options.name_IDs=['*'];options.name_legacy=True;options.name_languages=['*']
            sub=subset.Subsetter(options=options);sub.populate(text=text);sub.subset(font)
        # Honor reserved font names when distributing a subset/renamed derivative.
        family='MoveAnythingSans'+suffix.split('.')[0]
        for record in font['name'].names:
            if record.nameID in [1,3,4,6,16]:record.string=family.encode(record.getEncoding(),errors='replace')
        target=output/('MoveAnythingSans'+suffix);font.save(target)
        print(target.name,target.stat().st_size,'bytes')

if __name__=='__main__':main()
