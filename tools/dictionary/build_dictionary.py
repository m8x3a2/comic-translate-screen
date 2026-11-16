"""Builds the offline English -> Russian dictionary (one SQLite file) from kaikki.org Wiktionary dumps.

Usage: python -I build_dictionary.py <src_dir> <out.sqlite> <en_words.txt>
  src_dir: en.jsonl.gz      https://kaikki.org/dictionary/English/kaikki.org-dictionary-English.jsonl.gz
           ru-extract.jsonl.gz  https://kaikki.org/dictionary/downloads/ru/ru-extract.jsonl.gz
  en_words.txt: the frequency list of the app (apps/comic_translate/assets/dict/en_words.txt).
Kept: every word or phrase with a Russian translation, plus the frequent English words (English
definitions only); forms (ran -> run) of kept words. Data: Wiktionary (CC-BY-SA 4.0), extracted by
wiktextract / kaikki.org (Tatu Ylonen). Streams through a staging table: memory stays small.

Tables (read by ct_core OfflineDictionary):
  entry(w PRIMARY KEY lower-case word, word, data JSON) where data =
    {pos: {"tr": {sense: [Russian words]}, "ru": [{"g": Russian gloss, "t": [tags], "x": [[en, ru]]}],
           "en": [{"g": English gloss, "t": [tags], "x": [en]}], "of": ["plural of guy", ...]}}
  form(f lower-case form, lemma, note), meta(k, v).
"""
import gzip
import itertools
import json
import os
import sqlite3
import sys
import time

STRESS = '́'
KEEP_TAGS = {
    'informal', 'colloquial', 'slang', 'vulgar', 'offensive', 'derogatory', 'humorous', 'archaic', 'dated',
    'obsolete', 'rare', 'figuratively', 'idiomatic', 'British', 'US', 'UK', 'Internet', 'euphemistic', 'childish',
    'transitive', 'intransitive', 'countable', 'uncountable', 'plural', 'abbreviation', 'interjection',
}
LATE_TAGS = {'archaic', 'obsolete', 'dated', 'rare'}
MAX_SENSES = 12
MAX_EXAMPLES = 2


def clean_ru(s):
    return ' '.join(s.replace(STRESS, '').split())


def clean_tr(s):
    """'сдать pf trans.' -> 'сдать' (wiktextract sometimes leaves English notes after the word)."""
    out = []
    for tok in clean_ru(s).split():
        if any('a' <= c.lower() <= 'z' for c in tok):
            break
        out.append(tok)
    return ' '.join(out)


def norm(w):
    return ' '.join(w.replace('’', "'").lower().split())


def tags_of(s):
    return [t for t in s.get('tags', []) if t in KEEP_TAGS]


def short(text, n=220):
    text = ' '.join(text.split())
    return text if len(text) <= n else text[:n - 1] + '…'


def en_entry(e, add_form):
    word = e.get('word')
    p = {'en': [], 'tr': {}, 'of': []}
    for s in e.get('senses', []):
        gl = s.get('glosses') or []
        if not gl:
            continue
        if 'form-of' in s.get('tags', []) or 'alt-of' in s.get('tags', []):
            for of in (s.get('form_of') or s.get('alt_of') or []):
                lemma = of.get('word')
                if lemma and norm(lemma) != norm(word):
                    add_form(word, lemma, short(gl[-1], 80))
            if len(p['of']) < 4:
                p['of'].append(short(gl[-1], 120))
            continue
        if len(p['en']) >= MAX_SENSES:
            continue
        ex = [short(x['text']) for x in s.get('examples', []) if x.get('text')][:MAX_EXAMPLES]
        p['en'].append({'g': short(gl[-1], 300), 't': tags_of(s), 'x': ex})
    trs = [(t, t.get('sense') or '') for t in e.get('translations', [])]
    for s in e.get('senses', []):  # most translation tables are stored inside the sense they belong to
        gl = s.get('glosses') or ['']
        trs += [(t, t.get('sense') or gl[-1]) for t in s.get('translations', [])]
    for t, sense in trs:
        if t.get('lang_code') != 'ru' or not t.get('word'):
            continue
        lst = p['tr'].setdefault(short(sense, 120), [])
        ru = clean_tr(t['word'])
        if ru and ru not in lst and len(lst) < 10:
            lst.append(ru)
    for fm in e.get('forms', []):
        form, tags = fm.get('form'), fm.get('tags', [])
        if form and 'table-tags' not in tags and 'inflection-template' not in tags and norm(form) != norm(word):
            add_form(form, word, ', '.join(tags[:3]))
    p['en'].sort(key=lambda s: any(t in LATE_TAGS for t in s['t']))
    return {k: v for k, v in p.items() if v}


def ru_entry(e):
    p = {'ru': []}
    for s in e.get('senses', []):
        gl = s.get('glosses') or []
        if not gl or len(p['ru']) >= MAX_SENSES:
            continue
        ex = [[short(x['text']), short(clean_ru(x.get('translation') or ''))]
              for x in s.get('examples', [])[:MAX_EXAMPLES] if x.get('text')]
        p['ru'].append({'g': short(clean_ru(gl[-1]), 300), 't': s.get('tags', [])[:3], 'x': ex})
    return p if p['ru'] else {}


def main(src, out, words_file):
    freq = {line.split()[0].lower() for line in open(words_file, encoding='utf8') if line.strip()}
    if os.path.exists(out):
        os.remove(out)
    db = sqlite3.connect(out)
    db.execute('PRAGMA journal_mode=OFF')
    db.execute('PRAGMA synchronous=OFF')
    db.execute('CREATE TABLE stage(w TEXT, word TEXT, pos TEXT, src TEXT, data TEXT)')
    db.execute('CREATE TABLE form(f TEXT, lemma TEXT, note TEXT)')
    t0 = time.time()
    forms = []

    def add_form(form, lemma, note):
        forms.append((norm(form), lemma, note))
        if len(forms) >= 50000:
            db.executemany('INSERT INTO form VALUES(?,?,?)', forms)
            forms.clear()

    stage = []

    def put(row):
        stage.append(row)
        if len(stage) >= 20000:
            db.executemany('INSERT INTO stage VALUES(?,?,?,?,?)', stage)
            stage.clear()

    n = 0
    with gzip.open(os.path.join(src, 'en.jsonl.gz'), 'rt', encoding='utf8') as f:
        for line in f:
            n += 1
            if n % 200000 == 0:
                print(f'en {n} lines {time.time() - t0:.0f}s', flush=True)
            e = json.loads(line)
            if e.get('lang_code') != 'en' or not e.get('word') or not e.get('pos'):
                continue
            d = en_entry(e, add_form)
            if d:
                put((norm(e['word']), e['word'], e['pos'], 'en', json.dumps(d, ensure_ascii=False)))
    print(f'en done {n} lines, {time.time() - t0:.0f}s', flush=True)

    n = 0
    with gzip.open(os.path.join(src, 'ru-extract.jsonl.gz'), 'rt', encoding='utf8') as f:
        for line in f:
            n += 1
            if '"lang_code": "en"' not in line and '"lang_code":"en"' not in line:
                continue
            e = json.loads(line)
            if e.get('lang_code') != 'en' or not e.get('word'):
                continue
            d = ru_entry(e)
            if d:
                put((norm(e['word']), e['word'], e.get('pos') or 'other', 'ru', json.dumps(d, ensure_ascii=False)))
    db.executemany('INSERT INTO stage VALUES(?,?,?,?,?)', stage)
    db.executemany('INSERT INTO form VALUES(?,?,?)', forms)
    db.commit()
    print(f'ru done {n} lines, {time.time() - t0:.0f}s', flush=True)

    db.execute('CREATE INDEX stage_w ON stage(w)')
    db.execute('CREATE TABLE entry(w TEXT PRIMARY KEY, word TEXT, data TEXT)')
    db.execute('CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT)')
    db.executemany('INSERT INTO meta VALUES(?,?)', [
        ('format', '1'), ('from', 'en'), ('to', 'ru'), ('built', time.strftime('%Y-%m-%d')),
        ('source', 'Wiktionary (CC-BY-SA 4.0) via wiktextract/kaikki.org'),
    ])
    rows = []
    count = 0
    kept = set()
    cur = db.cursor()
    for w, group in itertools.groupby(cur.execute('SELECT w, word, pos, src, data FROM stage ORDER BY w, rowid'),
                                      key=lambda r: r[0]):
        merged, head = {}, None
        for _, word, pos, _src, data in group:
            head = head or word
            p = merged.setdefault(pos, {})
            for k, v in json.loads(data).items():
                if k == 'tr':
                    t = p.setdefault('tr', {})
                    for sense, lst in v.items():
                        tl = t.setdefault(sense, [])
                        tl += [x for x in lst if x not in tl]
                else:
                    p.setdefault(k, [])
                    p[k] += v[:MAX_SENSES - len(p[k])]
        russian = any('tr' in p or 'ru' in p for p in merged.values())
        if not russian and w not in freq:
            continue
        kept.add(w)
        if 'name' in merged:  # names (Guy) after the words
            merged['name'] = merged.pop('name')
        rows.append((w, head, json.dumps(merged, ensure_ascii=False, separators=(',', ':'))))
        count += 1
        if len(rows) >= 20000:
            db.executemany('INSERT INTO entry VALUES(?,?,?)', rows)
            rows.clear()
    db.executemany('INSERT INTO entry VALUES(?,?,?)', rows)
    db.execute('DROP TABLE stage')
    db.create_function('kept', 1, lambda lemma: norm(lemma) in kept, deterministic=True)
    db.execute('CREATE TABLE form2 AS SELECT DISTINCT f, lemma, note FROM form WHERE kept(lemma)')
    db.execute('DROP TABLE form')
    db.execute('ALTER TABLE form2 RENAME TO form')
    db.execute('CREATE INDEX form_f ON form(f)')
    db.commit()
    db.execute('VACUUM')
    nf = db.execute('SELECT count(*) FROM form').fetchone()[0]
    db.close()
    print(f'written {count} entries, {nf} forms, {os.path.getsize(out) / 1e6:.0f} MB, {time.time() - t0:.0f}s')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])
