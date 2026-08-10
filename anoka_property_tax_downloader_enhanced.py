#!/usr/bin/env python3
import csv, json, sys, time
from pathlib import Path

try:
    import requests
except ImportError:
    print("Install dependency with: py -m pip install requests")
    sys.exit(1)

SERVICE_ROOT = "https://gis.anokacountymn.gov/anoka_gis/rest/services/Parcels/MapServer/0"
QUERY_URL = SERVICE_ROOT + "/query"
PAGE_SIZE = 1000
TIMEOUT = 60
RETRIES = 5

ALL_OUTPUT = Path("Anoka_County_All_Parcels_Enhanced.csv")
SF_OUTPUT = Path("Anoka_County_Single_Family_Property_Taxes_Enhanced.csv")
FIELD_MAP_OUTPUT = Path("Anoka_County_ArcGIS_Field_Map.json")

FIELD_CANDIDATES = {
    "OBJECTID": ["OBJECTID", "FID"],
    "Parcel_ID": ["PIN", "PARCEL_ID", "PARCELID"],
    "Address": ["LOC_ADDR", "SITE_ADDR", "ADDRESS", "SITUS_ADDR"],
    "City": ["ACT_CITY", "CITY", "SITE_CITY"],
    "State": ["LOC_STATE", "STATE", "SITE_STATE"],
    "ZIP": ["LOC_ZIP", "ZIP", "ZIPCODE", "SITE_ZIP"],
    "Use_Code": ["USE_CODE", "USECODE"],
    "Use_Description": ["USE_DESC", "USE_DESCRIPTION", "USEDESC"],
    "Property_Class": ["PROP_CLASS", "PROPERTY_CLASS", "CLASS"],
    "Structure_Type": ["STRUC_TYPE", "STRUCTURE_TYPE", "STRUCT_TYPE"],
    "Homestead": ["HOMESTEAD", "HMSTD"],
    "Use_Program": ["USE_PRGM", "USE_PROGRAM"],
    "Tax_Year": ["TAX_YEAR", "TAXYEAR"],
    "Market_Value": ["MKT_VALUE", "MARKET_VALUE", "EMV"],
    "Land_Value": ["LAND_VALUE", "LANDVALUE"],
    "Building_Value": ["BLDG_VALUE", "BUILDING_VALUE", "BLDGVAL"],
    "Classified_Value": ["CLS_VALUE", "CLASSIFIED_VALUE"],
    "Total_Tax": ["TOTAL_TAX", "TOTALTAX", "NET_TAX"],
    "Special_Assessments": ["SPC_ASSESS", "SPECIAL_ASSESSMENTS", "SPEC_ASSESS"],
    "Living_Sq_Ft": ["LIV_SQ_FT", "LIVING_SQ_FT", "LIVINGAREA", "LIVING_AREA"],
    "Total_Sq_Ft": ["TOTAL_SQ_FT", "TOT_SQ_FT", "TOTALSF", "TOTAL_SF"],
    "Bedrooms": ["BEDROOMS", "BEDROOM", "BEDS", "NUM_BEDROOMS"],
    "Bathrooms": ["BATHROOMS", "BATHROOM", "BATHS", "NUM_BATHROOMS"],
    "Stories": ["STORIES", "STORY", "NUM_STORIES"],
    "Basement": ["BASEMENT", "BSMT", "BASEMENT_TYPE"],
    "Heating_Cooling": ["HEAT_COOL", "HEATING_COOLING", "HVAC", "HEAT", "COOLING"],
    "Year_Built": ["YEAR_BUILT", "YR_BUILT", "BUILT_YEAR"],
    "Effective_Year_Built": ["EFF_YEAR_BUILT", "EFFECTIVE_YEAR_BUILT", "EFF_YR_BUILT"],
    "Acres": ["ACRES", "GIS_ACRES", "PARCEL_ACRES"],
    "Deed_Acres": ["DEED_ACRES", "DEEDACRES"],
    "Neighborhood": ["NEIGHBORHOOD", "NBHD", "NEIGH_CODE", "NEIGHBORHOOD_CODE"],
    "Levy_Code": ["LEVY_CODE", "LEVYCODE", "TAX_DISTRICT", "TAX_DIST"],
    "Sale_Date": ["SALE_DATE", "LAST_SALE_DATE", "SALEDATE"],
    "Sale_Price": ["SALE_PRICE", "LAST_SALE_PRICE", "SALEPRICE"],
}
OUTPUT_FIELDS = list(FIELD_CANDIDATES)

def get_json(session, url, params=None):
    err = None
    for attempt in range(RETRIES):
        try:
            r = session.get(url, params=params, timeout=TIMEOUT)
            r.raise_for_status()
            d = r.json()
            if isinstance(d, dict) and "error" in d:
                raise RuntimeError(d["error"])
            return d
        except Exception as e:
            err = e
            if attempt < RETRIES - 1:
                time.sleep(min(2 ** (attempt + 1), 20))
    raise RuntimeError(f"Request failed: {err}")

def resolve_fields(meta):
    available = {f["name"].upper(): f["name"] for f in meta.get("fields", []) if f.get("name")}
    resolved, missing = {}, []
    for out, candidates in FIELD_CANDIDATES.items():
        found = next((available[c.upper()] for c in candidates if c.upper() in available), None)
        if found:
            resolved[out] = found
        else:
            missing.append(out)
    return resolved, missing

def text(v):
    return "" if v is None else str(v).strip()

def number(v):
    try:
        return float(v)
    except Exception:
        return None

def build_row(attrs, resolved):
    row = {out: attrs.get(resolved[out], "") if out in resolved else "" for out in OUTPUT_FIELDS}
    for k in ["Parcel_ID","Address","City","State","ZIP","Use_Code","Use_Description","Property_Class",
              "Structure_Type","Homestead","Use_Program","Basement","Heating_Cooling","Neighborhood","Levy_Code"]:
        row[k] = text(row.get(k))
    return row

def is_likely_single_family(row):
    combined = " | ".join([
        text(row.get("Use_Description")).lower(),
        text(row.get("Property_Class")).lower(),
        text(row.get("Structure_Type")).lower()
    ])
    excludes = ["apartment","condo","condominium","townhome","townhouse","duplex","triplex","fourplex",
                "multi family","multifamily","commercial","industrial","office","retail","warehouse",
                "agric","farm","vacant","land only","institution","school","church","government","mobile home park"]
    if any(x in combined for x in excludes):
        return False
    positives = ["single family","single-family","residential","residence","dwelling","home"]
    has_addr = bool(text(row.get("Address")))
    structure_signal = (
        (number(row.get("Building_Value")) or 0) > 0 or
        (number(row.get("Living_Sq_Ft")) or 0) > 0 or
        (number(row.get("Total_Sq_Ft")) or 0) > 0 or
        bool(text(row.get("Structure_Type")))
    )
    if "single family" in combined or "single-family" in combined:
        return has_addr
    return has_addr and structure_signal and any(x in combined for x in positives)

def write_csv(path, rows):
    with path.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=OUTPUT_FIELDS)
        w.writeheader()
        w.writerows(rows)

def main():
    s = requests.Session()
    s.headers["User-Agent"] = "AnokaCountyPropertyTaxResearch/2.0"
    meta = get_json(s, SERVICE_ROOT, {"f":"json"})
    resolved, missing = resolve_fields(meta)

    FIELD_MAP_OUTPUT.write_text(json.dumps({
        "service": SERVICE_ROOT,
        "resolved_output_fields": resolved,
        "unresolved_output_fields": missing,
        "available_fields": [{"name":f.get("name"),"alias":f.get("alias"),"type":f.get("type")} for f in meta.get("fields",[])]
    }, indent=2), encoding="utf-8")

    if "Parcel_ID" not in resolved or "OBJECTID" not in resolved:
        raise RuntimeError("Required parcel/PIN or OBJECTID field was not found.")

    src_fields = list(dict.fromkeys(resolved.values()))
    oid = resolved["OBJECTID"]

    all_rows, sf_rows = [], []
    offset = 0
    while True:
        params = {
            "f":"json","where":"1=1","outFields":",".join(src_fields),"returnGeometry":"false",
            "orderByFields":f"{oid} ASC","resultOffset":offset,"resultRecordCount":PAGE_SIZE
        }
        data = get_json(s, QUERY_URL, params)
        feats = data.get("features", [])
        if not feats:
            break
        for feat in feats:
            row = build_row(feat.get("attributes", {}), resolved)
            all_rows.append(row)
            if is_likely_single_family(row):
                sf_rows.append(row)
        offset += len(feats)
        print(f"Downloaded {offset:,} parcels ({len(sf_rows):,} likely single-family)")
        if len(feats) < PAGE_SIZE and not data.get("exceededTransferLimit"):
            break

    write_csv(ALL_OUTPUT, all_rows)
    write_csv(SF_OUTPUT, sf_rows)
    print(f"Created {ALL_OUTPUT}")
    print(f"Created {SF_OUTPUT}")
    print(f"Created {FIELD_MAP_OUTPUT}")
    if missing:
        print("Unresolved desired fields:", ", ".join(missing))

if __name__ == "__main__":
    main()
