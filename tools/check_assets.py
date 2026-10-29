"""Check font glyph coverage and fixed-width translated controls (requires fonttools)."""
from pathlib import Path
import json
from fontTools.ttLib import TTFont
from build_locales import LANGUAGES, generated_files

ROOT=Path(__file__).resolve().parents[1]
LIMITS={'Close':(80,11),'Reset':(90,11),'Reset All':(134,11),'Click again':(134,11),
        'Done Moving':(130,11),'Pick Frame':(130,11),'Move':(76,10),'Hide':(62,10),
        'Layout for:':(98,11),'All heroes':(150,10),'This hero':(150,10)}

def main():
    for name,text in generated_files().items():
        assert (ROOT/name).read_text(encoding='utf-8')==text, f'Regenerate {name}'
    names=['English','Polski','Čeština','Deutsch','Português (Brasil)','Español','Français',
           'Română','Türkçe','Русский','Українська','简体中文','日本語','한국어']
    for code in LANGUAGES:
        suffix='-'+code+'.otf' if code in ['zh','ja','ko'] else '.ttf'
        font=TTFont(ROOT/'MoveAnything/media'/('MoveAnythingSans'+suffix))
        cmap=font.getBestCmap();metrics=font['hmtx'].metrics;units=font['head'].unitsPerEm
        entries=json.loads((ROOT/'locales'/f'{code}.json').read_text(encoding='utf-8'))
        missing=sorted({ord(ch) for ch in ''.join(entries.values()) if not ch.isspace() and ord(ch) not in cmap})
        assert not missing,(code,'missing glyphs',missing)
        for key,(available,size) in LIMITS.items():
            width=sum(metrics[cmap[ord(ch)]][0] for ch in entries[key])*size/units
            assert width<=available-4,(code,key,round(width,1),available-4)
        label=entries['Language: %s'] % (entries['Automatic'] if code=='en' else names[LANGUAGES.index(code)])
        assert all(ord(ch) in cmap for ch in label), (code,'language label glyph')
    print('PASS: glyph coverage in all 14 catalogs and translated control widths')

if __name__=='__main__':main()
