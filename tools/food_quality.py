from __future__ import annotations

import csv
import json
import math
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


OUTPUT_FIELDS = (
    "id",
    "isim",
    "isim_ingilizce",
    "brand",
    "kalori100g",
    "protein100g",
    "karbonhidrat100g",
    "yag100g",
    "sodyum100g",
    "potasyum100g",
    "kolesterol100g",
    "lif100g",
    "seker100g",
    "doymus_yag100g",
    "isVerified",
)

CORE_MACRO_FIELDS = ("protein100g", "karbonhidrat100g", "yag100g")
GRAM_FIELDS = (
    "protein100g",
    "karbonhidrat100g",
    "yag100g",
    "lif100g",
    "seker100g",
    "doymus_yag100g",
)
MG_FIELDS = ("sodyum100g", "potasyum100g", "kolesterol100g")
NUMERIC_FIELDS = ("kalori100g", *GRAM_FIELDS, *MG_FIELDS)

MIN_KCAL = 1.0
MAX_KCAL = 900.0
MAX_GRAM = 100.0
SAFE_GRAM_CLAMP_MAX = 102.0
MAX_MG = 50_000.0
MACRO_SUM_SUSPECT_MAX = 105.0
ENERGY_RATIO_MIN = 0.45
ENERGY_RATIO_MAX = 1.65
RELATION_TOLERANCE = 0.5

PLACEHOLDER_NAMES = {
    "unknown",
    "none",
    "null",
    "test",
    "urun",
    "ürün",
    "gida",
    "gıda",
    "food",
    "product",
}


@dataclass(frozen=True)
class CleanDecision:
    status: str
    item: dict
    reasons: tuple[str, ...]
    source: str = ""
    index: int | None = None

    @property
    def is_valid(self) -> bool:
        return self.status == "valid"


def parse_float(value, default: float = 0.0) -> tuple[float, bool]:
    if value is None or value == "":
        return default, True
    if isinstance(value, bool):
        return default, False
    if isinstance(value, (int, float)):
        parsed = float(value)
        return parsed, math.isfinite(parsed)
    try:
        parsed = float(str(value).replace(",", "."))
    except (TypeError, ValueError):
        return default, False
    return parsed, math.isfinite(parsed)


def normalize_text(value) -> str:
    text = "" if value is None else str(value)
    text = text.replace("\u00a0", " ")
    text = unicodedata.normalize("NFC", text)
    text = text.replace("\u0307", "")
    text = " ".join(text.split())
    return unicodedata.normalize("NFC", text.strip())


def normalized_key(value) -> str:
    text = normalize_text(value).casefold()
    return "".join(ch for ch in text if ch.isalnum())


def name_brand_key(item: dict) -> tuple[str, str]:
    return (
        normalized_key(item.get("isim", "")),
        normalized_key(item.get("brand", "")),
    )


def _has_control_chars(text: str) -> bool:
    return any(ord(ch) < 32 and ch not in "\t\n\r" for ch in text)


def _has_html_or_url(text: str) -> bool:
    lowered = text.lower()
    return (
        ("<" in text and ">" in text)
        or "http://" in lowered
        or "https://" in lowered
        or "www." in lowered
    )


def _has_alpha(text: str) -> bool:
    return any(ch.isalpha() for ch in text)


def _round1(value: float) -> float:
    return round(float(value), 1)


def clean_item(raw: dict, *, source: str = "", index: int | None = None) -> CleanDecision:
    reasons: list[str] = []
    item: dict = {
        "id": normalize_text(raw.get("id")),
        "isim": normalize_text(raw.get("isim")),
        "isim_ingilizce": normalize_text(raw.get("isim_ingilizce")),
        "brand": normalize_text(raw.get("brand")),
        "isVerified": bool(raw.get("isVerified", False)),
    }

    name = item["isim"]
    if not name:
        reasons.append("invalid_name_empty")
    elif not _has_alpha(name):
        reasons.append("invalid_name_no_alpha")
    if name.lower() in PLACEHOLDER_NAMES:
        reasons.append("invalid_name_placeholder")
    if _has_control_chars(name):
        reasons.append("invalid_name_control_chars")
    if _has_html_or_url(name):
        reasons.append("invalid_name_html_or_url")
    if len(name) > 120:
        item["isim"] = name[:120].rstrip()
        reasons.append("normalized_name_truncated")

    for field in NUMERIC_FIELDS:
        value, ok = parse_float(raw.get(field), 0.0)
        if not ok:
            reasons.append(f"invalid_numeric_{field}")
            value = 0.0
        if value < 0:
            reasons.append(f"invalid_negative_{field}")
        if field == "kalori100g":
            if value < MIN_KCAL or value > MAX_KCAL:
                reasons.append("invalid_kcal_range")
        elif field in GRAM_FIELDS:
            if MAX_GRAM < value <= SAFE_GRAM_CLAMP_MAX:
                value = MAX_GRAM
                reasons.append(f"normalized_clamped_{field}")
            elif value > SAFE_GRAM_CLAMP_MAX:
                reasons.append(f"invalid_gram_range_{field}")
        elif field in MG_FIELDS and value > MAX_MG:
            reasons.append(f"invalid_mg_range_{field}")
        item[field] = _round1(value)

    hard_invalid = any(reason.startswith("invalid_") for reason in reasons)
    if hard_invalid:
        return CleanDecision("invalid", item, tuple(reasons), source, index)

    kcal = item["kalori100g"]
    protein = item["protein100g"]
    carb = item["karbonhidrat100g"]
    fat = item["yag100g"]
    sugar = item["seker100g"]
    sat_fat = item["doymus_yag100g"]

    if kcal > 0 and protein == 0 and carb == 0 and fat == 0:
        reasons.append("suspect_missing_core_macro")
    if protein + carb + fat > MACRO_SUM_SUSPECT_MAX:
        reasons.append("suspect_macro_sum_gt_105")

    macro_kcal = protein * 4 + carb * 4 + fat * 9
    if kcal >= 50 and macro_kcal >= 10:
        ratio = macro_kcal / kcal
        if ratio < ENERGY_RATIO_MIN or ratio > ENERGY_RATIO_MAX:
            reasons.append("suspect_macro_kcal_mismatch")

    if sugar > carb + RELATION_TOLERANCE:
        reasons.append("suspect_sugar_gt_carb")
    if sat_fat > fat + RELATION_TOLERANCE:
        reasons.append("suspect_satfat_gt_fat")

    status = "suspect" if any(r.startswith("suspect_") for r in reasons) else "valid"
    return CleanDecision(status, item, tuple(reasons), source, index)


def quality_score(item: dict) -> float:
    score = 0.0
    if item.get("isVerified"):
        score += 1000.0
    if normalize_text(item.get("brand")):
        score += 50.0
    if normalize_text(item.get("isim_ingilizce")):
        score += 10.0

    kcal = float(item.get("kalori100g") or 0)
    macro_kcal = (
        float(item.get("protein100g") or 0) * 4
        + float(item.get("karbonhidrat100g") or 0) * 4
        + float(item.get("yag100g") or 0) * 9
    )
    if kcal > 0 and macro_kcal > 0:
        score -= abs(1 - (macro_kcal / kcal)) * 100
    score += sum(1 for field in NUMERIC_FIELDS if float(item.get(field) or 0) > 0)
    score -= len(normalize_text(item.get("isim"))) / 500
    return score


def audit_records(records: Iterable[tuple[str, int, dict]]) -> tuple[list[dict], list[dict], dict]:
    valid_decisions: list[CleanDecision] = []
    suspects: list[dict] = []
    reason_counts: dict[str, int] = {}
    source_counts: dict[str, dict[str, int]] = {}
    input_count = 0

    def bump(reason: str) -> None:
        reason_counts[reason] = reason_counts.get(reason, 0) + 1

    def bump_source(source: str, status: str) -> None:
        source_bucket = source_counts.setdefault(source, {})
        source_bucket[status] = source_bucket.get(status, 0) + 1

    for source, index, raw in records:
        input_count += 1
        decision = clean_item(raw, source=source, index=index)
        for reason in decision.reasons:
            bump(reason)
        if decision.status == "valid":
            valid_decisions.append(decision)
            bump_source(source, "candidate_valid")
        else:
            suspects.append(_suspect_payload(decision, raw))
            bump_source(source, decision.status)

    grouped: dict[tuple[str, str], list[CleanDecision]] = {}
    for decision in valid_decisions:
        grouped.setdefault(name_brand_key(decision.item), []).append(decision)

    kept: list[dict] = []
    for group in grouped.values():
        if len(group) == 1:
            kept.append(group[0].item | {"_source": group[0].source})
            bump_source(group[0].source, "kept")
            continue
        group = sorted(group, key=lambda d: quality_score(d.item), reverse=True)
        winner = group[0]
        kept.append(winner.item | {"_source": winner.source})
        bump_source(winner.source, "kept")
        for duplicate in group[1:]:
            duplicate_decision = CleanDecision(
                "suspect",
                duplicate.item,
                (*duplicate.reasons, "suspect_duplicate_name_brand"),
                duplicate.source,
                duplicate.index,
            )
            bump("suspect_duplicate_name_brand")
            bump_source(duplicate.source, "suspect")
            suspects.append(_suspect_payload(duplicate_decision, None))

    kept.sort(key=lambda item: normalize_text(item.get("isim")).casefold())
    suspects.sort(key=lambda item: (item["source"], item["index"], item["id"]))
    summary = {
        "input_count": input_count,
        "kept_count": len(kept),
        "suspect_count": len(suspects),
        "reason_counts": dict(sorted(reason_counts.items())),
        "source_counts": source_counts,
    }
    return kept, suspects, summary


def strip_internal_fields(item: dict, *, include_brand: bool) -> dict:
    fields = OUTPUT_FIELDS if include_brand else tuple(f for f in OUTPUT_FIELDS if f != "brand")
    return {field: item.get(field, False if field == "isVerified" else "") for field in fields}


def write_json(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def write_suspects_csv(path: Path, suspects: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=("source", "index", "id", "isim", "brand", "status", "reasons"),
        )
        writer.writeheader()
        for suspect in suspects:
            writer.writerow(
                {
                    "source": suspect["source"],
                    "index": suspect["index"],
                    "id": suspect["id"],
                    "isim": suspect["isim"],
                    "brand": suspect["brand"],
                    "status": suspect["status"],
                    "reasons": "|".join(suspect["reasons"]),
                }
            )


def _suspect_payload(decision: CleanDecision, raw: dict | None) -> dict:
    item = decision.item
    return {
        "source": decision.source,
        "index": decision.index if decision.index is not None else -1,
        "id": item.get("id", ""),
        "isim": item.get("isim", ""),
        "brand": item.get("brand", ""),
        "status": decision.status,
        "reasons": list(decision.reasons),
        "item": item,
        "raw": raw,
    }
