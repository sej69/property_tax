#!/usr/bin/env python3
"""
Download Anoka County, Minnesota parcel/tax data from the county's public ArcGIS REST service
and save likely single-family residential parcels to CSV.

Output:
    Anoka_County_Single_Family_Property_Taxes.csv
    Anoka_County_All_Parcels.csv

Requirements:
    Python 3.10+
    pip install requests

Run:
    python anoka_property_tax_downloader.py
"""

import csv
import sys
import time
from pathlib import Path

try:
    import requests
except ImportError:
    print("Missing dependency: requests")
    print("Install it with: py -m pip install requests")
    sys.exit(1)

LAYER_URL = (
    "https://gis.anokacountymn.gov/anoka_gis/rest/services/"
    "Parcels_Tyler_StatePlane/MapServer/0/query"
)

FIELDS = [
    "OBJECTID",
    "PIN",
    "LOC_ADDR",
    "ACT_CITY",
    "LOC_STATE",
    "LOC_ZIP",
    "USE_CODE",
    "USE_DESC",
    "PROP_CLASS",
    "MKT_VALUE",
    "LAND_VALUE",
    "BLDG_VALUE",
    "CLS_VALUE",
    "HOMESTEAD",
    "TAX_YEAR",
    "TOTAL_TAX",
    "SPC_ASSESS",
    "USE_PRGM",
    "STRUC_TYPE",
    "YEAR_BUILT",
    "LIV_SQ_FT",
]

# County layer currently advertises MaxRecordCount=1000.
PAGE_SIZE = 1000
REQUEST_TIMEOUT = 60
MAX_RETRIES = 5

ALL_OUTPUT = Path("Anoka_County_All_Parcels.csv")
SF_OUTPUT = Path("Anoka_County_Single_Family_Property_Taxes.csv")


def get_json(session, params):
    last_exc = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            r = session.get(LAYER_URL, params=params, timeout=REQUEST_TIMEOUT)
            r.raise_for_status()
            data = r.json()
            if "error" in data:
                raise RuntimeError(f"ArcGIS error: {data['error']}")
            return data
        except Exception as exc:
            last_exc = exc
            if attempt == MAX_RETRIES:
                break
            delay = min(2 ** attempt, 20)
            print(f"Request failed ({exc}); retrying in {delay}s...")
            time.sleep(delay)
    raise RuntimeError(f"Request failed after {MAX_RETRIES} attempts: {last_exc}")


def normalize_text(value):
    return "" if value is None else str(value).strip()


def is_likely_single_family(attrs):
    """
    Conservative, inspectable classifier.

    Anoka County does not expose a simple documented boolean 'single family'
    field in this layer, so this uses USE_DESC / PROP_CLASS / STRUC_TYPE text.

    It excludes obvious multifamily, condo, apartment, commercial, industrial,
    agricultural, vacant-land, and institutional descriptions.

    The resulting CSV preserves the raw classification fields so you can audit
    or tighten this rule later.
    """
    use_desc = normalize_text(attrs.get("USE_DESC")).lower()
    prop_class = normalize_text(attrs.get("PROP_CLASS")).lower()
    struc_type = normalize_text(attrs.get("STRUC_TYPE")).lower()

    combined = " | ".join([use_desc, prop_class, struc_type])

    excludes = [
        "apartment",
        "condo",
        "condominium",
        "townhome",
        "townhouse",
        "duplex",
        "triplex",
        "fourplex",
        "multi family",
        "multifamily",
        "commercial",
        "industrial",
        "office",
        "retail",
        "warehouse",
        "agric",
        "farm",
        "vacant",
        "land only",
        "institution",
        "school",
        "church",
        "government",
        "mobile home park",
    ]
    if any(term in combined for term in excludes):
        return False

    positives = [
        "single family",
        "single-family",
        "residential",
        "residence",
        "dwelling",
        "home",
    ]

    # Strong direct signal.
    if "single family" in combined or "single-family" in combined:
        return True

    # Residential-looking parcel with a structure and a situs address.
    has_address = bool(normalize_text(attrs.get("LOC_ADDR")))
    has_building_value = (attrs.get("BLDG_VALUE") or 0) > 0
    has_structure = bool(struc_type)

    return (
        any(term in combined for term in positives)
        and has_address
        and (has_building_value or has_structure)
    )


def row_from_attrs(attrs):
    return {
        "Parcel_ID": normalize_text(attrs.get("PIN")),
        "Address": normalize_text(attrs.get("LOC_ADDR")),
        "City": normalize_text(attrs.get("ACT_CITY")),
        "State": normalize_text(attrs.get("LOC_STATE")),
        "ZIP": normalize_text(attrs.get("LOC_ZIP")),
        "Tax_Year": attrs.get("TAX_YEAR"),
        "Market_Value": attrs.get("MKT_VALUE"),
        "Land_Value": attrs.get("LAND_VALUE"),
        "Building_Value": attrs.get("BLDG_VALUE"),
        "Classified_Value": attrs.get("CLS_VALUE"),
        "Total_Tax": attrs.get("TOTAL_TAX"),
        "Special_Assessments": attrs.get("SPC_ASSESS"),
        "Use_Code": normalize_text(attrs.get("USE_CODE")),
        "Use_Description": normalize_text(attrs.get("USE_DESC")),
        "Property_Class": normalize_text(attrs.get("PROP_CLASS")),
        "Structure_Type": normalize_text(attrs.get("STRUC_TYPE")),
        "Homestead": normalize_text(attrs.get("HOMESTEAD")),
        "Use_Program": normalize_text(attrs.get("USE_PRGM")),
        "Year_Built": attrs.get("YEAR_BUILT"),
        "Living_Sq_Ft": attrs.get("LIV_SQ_FT"),
        "OBJECTID": attrs.get("OBJECTID"),
    }


def write_csv(path, rows):
    fieldnames = [
        "Parcel_ID",
        "Address",
        "City",
        "State",
        "ZIP",
        "Tax_Year",
        "Market_Value",
        "Land_Value",
        "Building_Value",
        "Classified_Value",
        "Total_Tax",
        "Special_Assessments",
        "Use_Code",
        "Use_Description",
        "Property_Class",
        "Structure_Type",
        "Homestead",
        "Use_Program",
        "Year_Built",
        "Living_Sq_Ft",
        "OBJECTID",
    ]
    with path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main():
    print("Downloading Anoka County parcel/tax data...")
    print(f"Source: {LAYER_URL}")

    session = requests.Session()
    session.headers.update(
        {"User-Agent": "AnokaCountyPropertyTaxResearch/1.0 (+manual research use)"}
    )

    all_rows = []
    sf_rows = []
    offset = 0

    while True:
        params = {
            "f": "json",
            "where": "1=1",
            "outFields": ",".join(FIELDS),
            "returnGeometry": "false",
            "orderByFields": "OBJECTID ASC",
            "resultOffset": offset,
            "resultRecordCount": PAGE_SIZE,
        }

        data = get_json(session, params)
        features = data.get("features", [])
        if not features:
            break

        for feature in features:
            attrs = feature.get("attributes", {})
            row = row_from_attrs(attrs)
            all_rows.append(row)
            if is_likely_single_family(attrs):
                sf_rows.append(row)

        offset += len(features)
        print(
            f"Downloaded {offset:,} parcels "
            f"({len(sf_rows):,} likely single-family)"
        )

        exceeded = bool(data.get("exceededTransferLimit"))
        if len(features) < PAGE_SIZE and not exceeded:
            break

    if not all_rows:
        raise RuntimeError("No parcel records were returned.")

    write_csv(ALL_OUTPUT, all_rows)
    write_csv(SF_OUTPUT, sf_rows)

    print()
    print("Complete.")
    print(f"All parcels:          {ALL_OUTPUT.resolve()}")
    print(f"Single-family subset: {SF_OUTPUT.resolve()}")
    print(f"Total parcels:        {len(all_rows):,}")
    print(f"Likely single-family: {len(sf_rows):,}")
    print()
    print(
        "Important: this public ArcGIS layer appears to contain one current "
        "tax-year snapshot per parcel. Historical tax-year collection should "
        "be joined later using Parcel_ID (PIN)."
    )


if __name__ == "__main__":
    main()
