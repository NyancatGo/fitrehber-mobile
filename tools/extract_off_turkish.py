"""
OpenFoodFacts JSONL dump'inden Turkiye'de satilan markali urunleri ayikla.

Kullanim:
    py tools/extract_off_turkish.py \
        --in  "C:/Users/baran/Downloads/openfoodfacts-products.jsonl.gz" \
        --out "assets/data/foods_brands_tr.json"

Cikti formati: foods_cleaned.json ile ayni schema + 'brand' alani.
"""
from __future__ import annotations

import argparse
import gzip
import io
import json
import sys
import time
from pathlib import Path

# Turkce'ye ozgu karakterler — product_name_tr'nin gercekten Turkce olup olmadigini
# anlamak icin. Yoksa OFF kullanicilari Ingilizce ismi Turkce field'a da yaziyor
# ve filter "Greek Yogurt"u Turk urunu sanip kabul ediyor.
TURKISH_LETTERS = set('çğıöşüÇĞİÖŞÜ')

# countries_tags'ta gecmesi gereken kesin tag
TURKEY_COUNTRY_TAG = 'en:turkey'

# Hedef cikti alanlari
OUTPUT_FIELDS = (
    'id', 'isim', 'isim_ingilizce', 'brand',
    'kalori100g', 'protein100g', 'karbonhidrat100g', 'yag100g',
    'sodyum100g', 'potasyum100g', 'kolesterol100g',
    'lif100g', 'seker100g', 'doymus_yag100g',
    'isVerified',
)

# Sanity check sinirleri (100g basina)
MAX_KCAL = 900           # saf yag bile 884 kcal
MAX_MACRO_G = 100        # 100g icinde 100g'dan fazla makro olamaz
MAX_MG = 50_000          # 50g/100g sodyum/potasyum vs. saçma
MIN_KCAL = 1             # 0 kalori = anlamsiz


def _f(v, default=0.0):
    """Sayisal degeri float'a cevirir, hatali ise default."""
    if v is None:
        return default
    if isinstance(v, (int, float)):
        return float(v)
    try:
        return float(str(v).replace(',', '.'))
    except (ValueError, TypeError):
        return default


def is_turkish_product(d: dict) -> bool:
    """Bir kaydin Turk pazarinda satildigini tespit eder. Iki kanit kabul edilir:
       1) countries_tags icinde 'en:turkey'
       2) product_name_tr dolu VE Turkce karakter iceriyor (sahte TR isimlerini ele)
    """
    countries_tags = d.get('countries_tags') or []
    if isinstance(countries_tags, list):
        for tag in countries_tags:
            if isinstance(tag, str) and tag.lower() == TURKEY_COUNTRY_TAG:
                return True

    tr_name = (d.get('product_name_tr') or '').strip()
    if tr_name and any(ch in TURKISH_LETTERS for ch in tr_name):
        return True

    return False


def passes_sanity(kcal: float, p: float, c: float, f: float,
                  sodium_mg: float, potassium_mg: float,
                  cholesterol_mg: float) -> bool:
    if kcal < MIN_KCAL or kcal > MAX_KCAL:
        return False
    if p < 0 or p > MAX_MACRO_G:
        return False
    if c < 0 or c > MAX_MACRO_G:
        return False
    if f < 0 or f > MAX_MACRO_G:
        return False
    if sodium_mg < 0 or sodium_mg > MAX_MG:
        return False
    if potassium_mg < 0 or potassium_mg > MAX_MG:
        return False
    if cholesterol_mg < 0 or cholesterol_mg > MAX_MG:
        return False
    if p == 0 and c == 0 and f == 0:
        # Kalori var ama hicbir makro yok → eksik veri
        return False
    return True


def build_name(d: dict, brand: str) -> str:
    raw_tr = (d.get('product_name_tr') or '').strip()
    raw_default = (d.get('product_name') or '').strip()
    base = raw_tr or raw_default
    if not base:
        return ''
    name = base
    if brand:
        # Brand zaten isim icinde geciyorsa tekrarlamayalim
        if brand.lower() not in base.lower():
            name = f'{brand} {base}'
    # Temizle
    name = ' '.join(name.split())  # cift bosluk
    if len(name) > 100:
        name = name[:100].rstrip()
    return name


def build_brand(d: dict) -> str:
    brands = (d.get('brands') or '').strip()
    if not brands:
        return ''
    # Virgulle ayrilmis ilk marka
    first = brands.split(',')[0].strip()
    if not first:
        return ''
    # Title case ama "ABC" gibi kisaltmalari koru
    if first.isupper() and len(first) <= 4:
        return first
    return first.title()


def transform(d: dict) -> dict | None:
    """Tek bir OFF kaydini bizim formatimiza cevirir, gecerli degilse None doner."""
    if not is_turkish_product(d):
        return None

    nutri = d.get('nutriments') or {}
    if not isinstance(nutri, dict):
        return None

    kcal = _f(nutri.get('energy-kcal_100g'))
    if kcal < MIN_KCAL:
        # Bazi kayitlarda sadece kJ var
        ej = _f(nutri.get('energy_100g'))
        if ej > 0:
            kcal = round(ej / 4.184, 1)

    protein = _f(nutri.get('proteins_100g'))
    carb = _f(nutri.get('carbohydrates_100g'))
    fat = _f(nutri.get('fat_100g'))
    fiber = _f(nutri.get('fiber_100g'))
    sugar = _f(nutri.get('sugars_100g'))
    sat_fat = _f(nutri.get('saturated-fat_100g'))

    # OFF sodium/potassium/cholesterol gram cinsinden, biz mg istiyoruz
    sodium_mg = _f(nutri.get('sodium_100g')) * 1000
    potassium_mg = _f(nutri.get('potassium_100g')) * 1000
    cholesterol_mg = _f(nutri.get('cholesterol_100g')) * 1000

    if not passes_sanity(kcal, protein, carb, fat,
                         sodium_mg, potassium_mg, cholesterol_mg):
        return None

    brand = build_brand(d)
    name = build_name(d, brand)
    if not name:
        return None

    code = str(d.get('code') or d.get('_id') or '').strip()
    if not code:
        return None

    name_en = (d.get('product_name_en') or d.get('product_name') or '').strip()

    return {
        'id': code,
        'isim': name,
        'isim_ingilizce': name_en,
        'brand': brand,
        'kalori100g': round(kcal, 1),
        'protein100g': round(protein, 1),
        'karbonhidrat100g': round(carb, 1),
        'yag100g': round(fat, 1),
        'sodyum100g': round(sodium_mg, 1),
        'potasyum100g': round(potassium_mg, 1),
        'kolesterol100g': round(cholesterol_mg, 1),
        'lif100g': round(fiber, 1),
        'seker100g': round(sugar, 1),
        'doymus_yag100g': round(sat_fat, 1),
        'isVerified': False,
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--in', dest='inp', required=True, help='Input .jsonl.gz')
    p.add_argument('--out', dest='out', required=True, help='Output .json')
    p.add_argument('--stats', dest='stats', default=None,
                   help='Optional stats output path')
    p.add_argument('--max', type=int, default=0,
                   help='Max output records (0 = unlimited)')
    args = p.parse_args()

    in_path = Path(args.inp)
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    stats = {
        'total_lines': 0,
        'parse_errors': 0,
        'not_turkish': 0,
        'no_nutriments': 0,
        'sanity_fail': 0,
        'no_name': 0,
        'duplicate_code': 0,
        'accepted': 0,
    }

    seen_codes: set[str] = set()
    results: list[dict] = []
    start = time.time()
    last_report = start

    print(f'[start] reading {in_path}', flush=True)
    with gzip.open(in_path, 'rb') as gz:
        # Buffered text reader (utf-8). Bazi kayitlarin invalid utf-8 olmasi
        # ihtimaline karsi errors='replace'.
        reader = io.TextIOWrapper(gz, encoding='utf-8', errors='replace')
        for line in reader:
            stats['total_lines'] += 1
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                stats['parse_errors'] += 1
                continue

            if not is_turkish_product(d):
                stats['not_turkish'] += 1
            else:
                nutri = d.get('nutriments')
                if not isinstance(nutri, dict) or not nutri:
                    stats['no_nutriments'] += 1
                else:
                    item = transform(d)
                    if item is None:
                        # transform None dondurdu → sanity fail veya no name
                        # Hangisi oldugunu tekrar hesaplamak yerine genel 'sanity_fail' sayalim
                        stats['sanity_fail'] += 1
                    elif item['id'] in seen_codes:
                        stats['duplicate_code'] += 1
                    else:
                        seen_codes.add(item['id'])
                        results.append(item)
                        stats['accepted'] += 1
                        if args.max and len(results) >= args.max:
                            print(f'[stop] reached --max={args.max}', flush=True)
                            break

            now = time.time()
            if now - last_report > 5:
                elapsed = now - start
                rate = stats['total_lines'] / elapsed if elapsed else 0
                print(
                    f'[progress] lines={stats["total_lines"]:>9,} '
                    f'accepted={stats["accepted"]:>6,} '
                    f'rate={rate:,.0f}/s '
                    f'elapsed={elapsed:.0f}s',
                    flush=True,
                )
                last_report = now

    # Sirala (isim alfabetik)
    results.sort(key=lambda x: x['isim'].lower())

    # Yaz
    print(f'[write] {out_path}', flush=True)
    out_path.write_text(
        json.dumps(results, ensure_ascii=False, indent=2),
        encoding='utf-8',
    )

    # Stats
    elapsed = time.time() - start
    stats['elapsed_sec'] = round(elapsed, 1)
    stats['output_bytes'] = out_path.stat().st_size
    stats_text = json.dumps(stats, ensure_ascii=False, indent=2)
    print('\n=== STATS ===')
    print(stats_text)

    if args.stats:
        Path(args.stats).write_text(stats_text, encoding='utf-8')

    print(f'\n[done] {stats["accepted"]:,} kayit yazildi, '
          f'{stats["output_bytes"]/1024:.1f} KB, {elapsed:.0f}s')


if __name__ == '__main__':
    sys.exit(main() or 0)
