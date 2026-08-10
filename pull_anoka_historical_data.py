#!/usr/bin/env python3
"""
Create a local, auditable Anoka County single-family tax-history snapshot.

This script is deliberately network-gated. It will not contact Anoka County
unless --acknowledge-county-pull is supplied.

Default requested history: tax years 2020 through 2026, inclusive.

The script expects an ArcGIS layer that actually contains historical rows. The
current parcel layer in this repository appears to contain only a 2026
snapshot. If the configured layer does not contain every requested year, the
script writes a missing-data report and does not fetch geometry.

Usage:
    py .\pull_anoka_historical_data.py
    py .\pull_anoka_historical_data.py --acknowledge-county-pull

If the county provides a separate historical layer, pass it explicitly:
    py .\pull_anoka_historical_data.py \
        --acknowledge-county-pull \
        --history-service-root "https://.../MapServer/0"

Dependency:
    py -m pip install requests
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
import time
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

DEFAULT_HISTORY_SERVICE_ROOT = (
    "https://gis.anokacountymn.gov/anoka_gis/rest/services/Parcels/MapServer/0"
)
DEFAULT_GEOMETRY_SERVICE_ROOT = DEFAULT_HISTORY_SERVICE_ROOT
DEFAULT_PAGE_SIZE = 1000
DEFAULT_TIMEOUT = 60
DEFAULT_RETRIES = 5
DEFAULT_DELAY_SECONDS = 0.25
DEFAULT_START_YEAR = 2020
DEFAULT_END_YEAR = 2026
PARCEL_ID_WIDTH = 12

DEFAULT_POPULATION_FILES = (
    Path("Anoka_County_Single_Family_Property_Taxes_Enhanced.csv"),
    Path("save") / "Anoka_County_Single_Family_Property_Taxes.csv",
)

FIELD_CANDIDATES = {
    "OBJECTID": ["OBJECTID", "FID"],
    "Parcel_ID": ["PIN", "PARCEL_ID", "PARCELID"],
    "Address": ["LOC_ADDR", "SITE_ADDR", "ADDRESS", "SITUS_ADDR"],
    "City": ["ACT_CITY", "CITY", "SITE_CITY", "LOC_CITY"],
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
    "Special_Assessments": [
        "SPC_ASSESS",
        "SPECIAL_ASSESSMENTS",
        "SPEC_ASSESS",
    ],
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

OUTPUT_FIELDS = [
    "Parcel_ID",
    "Tax_Year",
    "Address",
    "City",
    "State",
    "ZIP",
    "Use_Code",
    "Use_Description",
    "Property_Class",
    "Structure_Type",
    "Homestead",
    "Use_Program",
    "Neighborhood",
    "Levy_Code",
    "Market_Value",
    "Land_Value",
    "Building_Value",
    "Classified_Value",
    "Total_Tax",
    "Special_Assessments",
    "Living_Sq_Ft",
    "Total_Sq_Ft",
    "Bedrooms",
    "Bathrooms",
    "Stories",
    "Basement",
    "Heating_Cooling",
    "Year_Built",
    "Effective_Year_Built",
    "Acres",
    "Deed_Acres",
    "Sale_Date",
    "Sale_Price",
    "OBJECTID",
]


def text(value: Any) -> str:
    return "" if value is None else str(value).strip()


def normalize_pin(value: Any) -> str:
    """Return a canonical 12-character parcel ID without numeric coercion.

    ArcGIS may describe a PIN as a numeric field even though it is an
    identifier. If the JSON value arrives as a number, Python cannot recover
    formatting from the response; the county PIN width lets us restore the
    leading zeroes deterministically. Text PINs are preserved and only
    normalized for surrounding whitespace.
    """
    raw = text(value)
    if not raw:
        return ""
    if raw.endswith(".0") and raw[:-2].isdigit():
        raw = raw[:-2]
    if raw.isdigit():
        return raw.zfill(PARCEL_ID_WIDTH)
    return raw


def parse_year(value: Any) -> int | None:
    raw = text(value)
    if not raw:
        return None
    try:
        return int(float(raw))
    except (TypeError, ValueError):
        return None


def number(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def resolve_fields(metadata: dict[str, Any]) -> tuple[dict[str, str], list[str]]:
    available = {
        text(field.get("name")).upper(): text(field.get("name"))
        for field in metadata.get("fields", [])
        if text(field.get("name"))
    }
    resolved: dict[str, str] = {}
    missing: list[str] = []
    for output_name, candidates in FIELD_CANDIDATES.items():
        match = next(
            (available[candidate.upper()] for candidate in candidates if candidate.upper() in available),
            None,
        )
        if match:
            resolved[output_name] = match
        else:
            missing.append(output_name)
    return resolved, missing


def build_row(attributes: dict[str, Any], resolved: dict[str, str]) -> dict[str, Any]:
    row: dict[str, Any] = {}
    for output_name in OUTPUT_FIELDS:
        source_name = resolved.get(output_name)
        value = attributes.get(source_name, "") if source_name else ""
        if output_name in {
            "Parcel_ID",
            "Address",
            "City",
            "State",
            "ZIP",
            "Use_Code",
            "Use_Description",
            "Property_Class",
            "Structure_Type",
            "Homestead",
            "Use_Program",
            "Basement",
            "Heating_Cooling",
            "Neighborhood",
            "Levy_Code",
        }:
            value = text(value)
        row[output_name] = value
    row["Parcel_ID"] = normalize_pin(row.get("Parcel_ID"))
    row["Tax_Year"] = parse_year(row.get("Tax_Year"))
    return row


def is_likely_single_family(row: dict[str, Any]) -> bool:
    combined = " | ".join(
        text(row.get(field)).lower()
        for field in ("Use_Description", "Property_Class", "Structure_Type")
    )
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

    has_address = bool(text(row.get("Address")))
    has_structure = bool(text(row.get("Structure_Type")))
    has_building_value = number(row.get("Building_Value")) > 0
    has_living_area = number(row.get("Living_Sq_Ft")) > 0
    positive = any(
        term in combined
        for term in ("single family", "single-family", "residential", "residence", "dwelling", "home")
    )
    direct_single_family = "single family" in combined or "single-family" in combined
    if direct_single_family:
        return has_address
    return has_address and positive and (has_structure or has_building_value or has_living_area)


def get_json(
    session: requests.Session,
    url: str,
    params: dict[str, Any],
    retries: int,
    timeout: int,
    delay_seconds: float,
) -> dict[str, Any]:
    last_error: Exception | None = None
    for attempt in range(retries):
        try:
            response = session.get(url, params=params, timeout=timeout)
            response.raise_for_status()
            data = response.json()
            if isinstance(data, dict) and "error" in data:
                raise RuntimeError(f"ArcGIS error: {data['error']}")
            if not isinstance(data, dict):
                raise RuntimeError("ArcGIS response was not a JSON object")
            return data
        except Exception as exc:  # network and service errors are retriable
            last_error = exc
            if attempt + 1 < retries:
                wait = min(2 ** (attempt + 1), 20)
                print(f"Request failed ({exc}); retrying in {wait}s...", file=sys.stderr)
                time.sleep(wait)
    raise RuntimeError(f"Request failed after {retries} attempts: {last_error}")


def fetch_metadata(
    session: requests.Session,
    service_root: str,
    args: argparse.Namespace,
) -> dict[str, Any]:
    return get_json(
        session,
        service_root,
        {"f": "json"},
        args.retries,
        args.timeout,
        args.delay_seconds,
    )


def iter_features(
    session: requests.Session,
    service_root: str,
    source_fields: Iterable[str],
    object_id: str | None,
    args: argparse.Namespace,
    output_format: str = "json",
    return_geometry: bool = False,
) -> Iterable[dict[str, Any]]:
    query_url = service_root.rstrip("/") + "/query"
    offset = 0
    source_fields_string = ",".join(dict.fromkeys(source_fields))

    while True:
        params: dict[str, Any] = {
            "f": output_format,
            "where": "1=1",
            "outFields": source_fields_string,
            "returnGeometry": "true" if return_geometry else "false",
            "resultOffset": offset,
            "resultRecordCount": args.page_size,
        }
        if object_id:
            params["orderByFields"] = f"{object_id} ASC"
        if return_geometry:
            params["outSR"] = "4326"

        data = get_json(
            session,
            query_url,
            params,
            args.retries,
            args.timeout,
            args.delay_seconds,
        )
        features = data.get("features", [])
        if not features:
            break

        yield from features
        offset += len(features)
        print(f"Downloaded {offset:,} records from {service_root}")

        if len(features) < args.page_size and not data.get("exceededTransferLimit"):
            break
        if args.delay_seconds:
            time.sleep(args.delay_seconds)


def choose_population_file(explicit: str | None) -> Path | None:
    if explicit:
        path = Path(explicit)
        return path if path.exists() else None
    return next((path for path in DEFAULT_POPULATION_FILES if path.exists()), None)


def load_local_population(path: Path) -> tuple[set[str], dict[str, dict[str, Any]]]:
    population: set[str] = set()
    details: dict[str, dict[str, Any]] = {}
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            pin = normalize_pin(row.get("Parcel_ID"))
            if not pin:
                continue
            population.add(pin)
            details.setdefault(pin, row)
    return population, details


def write_csv(path: Path, fieldnames: list[str], rows: Iterable[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def geometry_centroid(geometry: dict[str, Any] | None) -> tuple[float, float] | None:
    if not geometry:
        return None
    if geometry.get("type") == "Point":
        coordinates = geometry.get("coordinates", [])
        if len(coordinates) >= 2:
            return float(coordinates[0]), float(coordinates[1])

    points: list[tuple[float, float]] = []

    def collect(value: Any) -> None:
        if isinstance(value, list) and len(value) >= 2 and all(
            isinstance(item, (int, float)) for item in value[:2]
        ):
            points.append((float(value[0]), float(value[1])))
            return
        if isinstance(value, list):
            for item in value:
                collect(item)

    collect(geometry.get("coordinates"))
    if not points:
        return None
    return (
        sum(point[0] for point in points) / len(points),
        sum(point[1] for point in points) / len(points),
    )


def pull_geometry(
    session: requests.Session,
    service_root: str,
    target_pins: set[str],
    population_details: dict[str, dict[str, Any]],
    resolved: dict[str, str],
    metadata: dict[str, Any],
    args: argparse.Namespace,
    output_dir: Path,
) -> dict[str, int]:
    geometry_path = output_dir / "single_family_parcels.geojson"
    centroid_path = output_dir / "single_family_centroids.csv"
    object_id = resolved.get("OBJECTID")
    parcel_field = resolved.get("Parcel_ID")
    if not parcel_field:
        raise RuntimeError("Geometry service did not expose a parcel/PIN field.")

    features_written = 0
    features_missing_geometry = 0
    seen_pins: set[str] = set()
    centroid_rows: list[dict[str, Any]] = []
    source_features = iter_features(
        session,
        service_root,
        [field for field in (parcel_field, object_id) if field],
        object_id,
        args,
        output_format="geojson",
        return_geometry=True,
    )

    with geometry_path.open("w", encoding="utf-8") as handle:
        handle.write('{"type":"FeatureCollection","features":[\n')
        first = True
        for feature in source_features:
            properties = feature.get("properties") or {}
            pin = normalize_pin(properties.get(parcel_field))
            if pin not in target_pins or pin in seen_pins:
                continue
            seen_pins.add(pin)
            geometry = feature.get("geometry")
            local = population_details.get(pin, {})
            output_feature = {
                "type": "Feature",
                "id": properties.get(object_id) if object_id else pin,
                "properties": {
                    "Parcel_ID": pin,
                    "Address": text(local.get("Address")),
                    "City": text(local.get("City")),
                    "State": text(local.get("State")),
                    "ZIP": text(local.get("ZIP")),
                },
                "geometry": geometry,
            }
            if not first:
                handle.write(",\n")
            handle.write(json.dumps(output_feature, ensure_ascii=False, separators=(",", ":")))
            first = False
            features_written += 1

            centroid = geometry_centroid(geometry)
            if centroid is None:
                features_missing_geometry += 1
            else:
                centroid_rows.append(
                    {
                        "Parcel_ID": pin,
                        "Longitude": centroid[0],
                        "Latitude": centroid[1],
                        "Address": text(local.get("Address")),
                        "City": text(local.get("City")),
                        "State": text(local.get("State")),
                        "ZIP": text(local.get("ZIP")),
                    }
                )
        handle.write('\n]}\n')

    write_csv(
        centroid_path,
        ["Parcel_ID", "Longitude", "Latitude", "Address", "City", "State", "ZIP"],
        centroid_rows,
    )
    return {
        "target_pins": len(target_pins),
        "geometry_features_written": features_written,
        "geometry_features_missing_geometry": features_missing_geometry,
        "geometry_target_pins_not_found": len(target_pins - seen_pins),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Pull a gated local Anoka County single-family tax-history snapshot."
    )
    parser.add_argument(
        "--acknowledge-county-pull",
        action="store_true",
        help="Explicitly authorize requests to the configured Anoka County GIS services.",
    )
    parser.add_argument("--start-year", type=int, default=DEFAULT_START_YEAR)
    parser.add_argument("--end-year", type=int, default=DEFAULT_END_YEAR)
    parser.add_argument("--history-service-root", default=DEFAULT_HISTORY_SERVICE_ROOT)
    parser.add_argument("--geometry-service-root", default=DEFAULT_GEOMETRY_SERVICE_ROOT)
    parser.add_argument("--population-file", help="Local current single-family CSV used as the PIN population.")
    parser.add_argument(
        "--output-dir",
        default=None,
        help="Output directory. Defaults to anoka_pull_<UTC timestamp>.",
    )
    parser.add_argument("--page-size", type=int, default=DEFAULT_PAGE_SIZE)
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT)
    parser.add_argument("--retries", type=int, default=DEFAULT_RETRIES)
    parser.add_argument("--delay-seconds", type=float, default=DEFAULT_DELAY_SECONDS)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.start_year > args.end_year:
        print("--start-year must be less than or equal to --end-year.", file=sys.stderr)
        return 2
    if args.page_size < 1 or args.page_size > 1000:
        print("--page-size must be between 1 and 1000.", file=sys.stderr)
        return 2

    output_dir = Path(args.output_dir) if args.output_dir else Path(
        "anoka_pull_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    )
    if output_dir.exists() and any(output_dir.iterdir()):
        print(f"Refusing to use non-empty output directory: {output_dir}", file=sys.stderr)
        print("Choose another --output-dir.", file=sys.stderr)
        return 2
    output_dir.mkdir(parents=True, exist_ok=True)

    requested_years = list(range(args.start_year, args.end_year + 1))
    population_file = choose_population_file(args.population_file)
    plan = {
        "requested_years": requested_years,
        "history_service_root": args.history_service_root,
        "geometry_service_root": args.geometry_service_root,
        "population_file": str(population_file) if population_file else None,
        "output_dir": str(output_dir.resolve()),
    }
    write_json(output_dir / "pull_plan.json", plan)

    if not args.acknowledge_county_pull:
        print("No county request was made.")
        print("A pull plan was written to:", output_dir / "pull_plan.json")
        print()
        print("To authorize the one-time pull, rerun with:")
        print("  py .\\pull_anoka_historical_data.py --acknowledge-county-pull")
        return 2

    try:
        import requests
    except ImportError:  # pragma: no cover - exercised when dependency is absent
        print("Missing dependency: requests", file=sys.stderr)
        print("Install it with: py -m pip install requests", file=sys.stderr)
        return 2

    if population_file:
        target_pins, population_details = load_local_population(population_file)
        if not target_pins:
            print(f"Population file contains no Parcel_ID values: {population_file}", file=sys.stderr)
            return 2
        population_basis = f"local file: {population_file}"
    else:
        target_pins = set()
        population_details = {}
        population_basis = "historical rows classified locally"

    session = requests.Session()
    session.headers.update({"User-Agent": "AnokaCountyPropertyTaxResearch/3.0"})

    print("Explicit county-pull acknowledgement received.")
    print("Requested years:", ", ".join(map(str, requested_years)))
    print("Population basis:", population_basis)
    print("Output directory:", output_dir.resolve())

    try:
        history_metadata = fetch_metadata(session, args.history_service_root, args)
        resolved, missing_fields = resolve_fields(history_metadata)
        required_missing = [field for field in ("Parcel_ID", "Tax_Year") if field not in resolved]
        if required_missing:
            report = {
                "complete": False,
                "reason": "Required fields are missing from the configured history service.",
                "missing_required_fields": required_missing,
                "resolved_fields": resolved,
                "service": args.history_service_root,
            }
            write_json(output_dir / "missing_data_report.json", report)
            print("Missing required fields. See", output_dir / "missing_data_report.json")
            return 3

        object_id = resolved.get("OBJECTID")
        source_fields = list(dict.fromkeys(resolved.values()))
        years_seen: set[int] = set()
        years_by_pin: defaultdict[str, set[int]] = defaultdict(set)
        records_written = 0
        tax_path = output_dir / "single_family_tax_history_partial.csv"

        with tax_path.open("w", encoding="utf-8-sig", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS, extrasaction="ignore")
            writer.writeheader()
            for feature in iter_features(
                session,
                args.history_service_root,
                source_fields,
                object_id,
                args,
                output_format="json",
                return_geometry=False,
            ):
                row = build_row(feature.get("attributes") or {}, resolved)
                year = row.get("Tax_Year")
                pin = normalize_pin(row.get("Parcel_ID"))
                if year is not None:
                    years_seen.add(year)
                if year not in requested_years or not pin:
                    continue

                if not target_pins:
                    if is_likely_single_family(row):
                        target_pins.add(pin)
                        population_details.setdefault(pin, row)
                    else:
                        continue
                if pin not in target_pins:
                    continue

                writer.writerow(row)
                years_by_pin[pin].add(year)
                records_written += 1

        missing_years = [year for year in requested_years if year not in years_seen]
        coverage_rows = []
        for pin in sorted(target_pins):
            present = sorted(years_by_pin.get(pin, set()))
            missing = [year for year in requested_years if year not in present]
            coverage_rows.append(
                {
                    "Parcel_ID": pin,
                    "Years_Present": ",".join(map(str, present)),
                    "Missing_Years": ",".join(map(str, missing)),
                    "Complete_History": "yes" if not missing else "no",
                }
            )
        write_csv(
            output_dir / "single_family_history_coverage.csv",
            ["Parcel_ID", "Years_Present", "Missing_Years", "Complete_History"],
            coverage_rows,
        )

        complete = not missing_years and all(
            row["Complete_History"] == "yes" for row in coverage_rows
        )
        manifest: dict[str, Any] = {
            "complete": complete,
            "requested_years": requested_years,
            "source_years_seen": sorted(years_seen),
            "source_years_missing_globally": missing_years,
            "population_basis": population_basis,
            "population_file": str(population_file) if population_file else None,
            "target_single_family_pins": len(target_pins),
            "tax_history_records_written": records_written,
            "history_service_root": args.history_service_root,
            "geometry_service_root": args.geometry_service_root,
            "resolved_history_fields": resolved,
            "unresolved_optional_fields": [field for field in missing_fields if field not in {"Parcel_ID", "Tax_Year"}],
            "created_utc": datetime.now(timezone.utc).isoformat(),
        }
        write_json(output_dir / "pull_manifest.json", manifest)

        if not complete:
            report = {
                "complete": False,
                "reason": "The configured source does not provide complete seven-year coverage for the target PINs.",
                "requested_years": requested_years,
                "source_years_seen": sorted(years_seen),
                "missing_years_globally": missing_years,
                "target_single_family_pins": len(target_pins),
                "partial_tax_history": str(tax_path),
                "coverage_report": str(output_dir / "single_family_history_coverage.csv"),
                "next_step": "Provide a historical ArcGIS layer with rows for the missing years and rerun with --history-service-root.",
            }
            write_json(output_dir / "missing_data_report.json", report)
            print("\nPULL INCOMPLETE: historical data is missing.")
            print("Missing years globally:", ", ".join(map(str, missing_years)) or "none")
            print("See:", output_dir / "missing_data_report.json")
            print("No geometry request was made because the requested history is incomplete.")
            return 3

        tax_complete_path = output_dir / "single_family_tax_history.csv"
        tax_path.replace(tax_complete_path)

        geometry_metadata = fetch_metadata(session, args.geometry_service_root, args)
        geometry_resolved, geometry_missing = resolve_fields(geometry_metadata)
        if "Parcel_ID" not in geometry_resolved:
            raise RuntimeError("Geometry service did not expose a parcel/PIN field.")
        geometry_summary = pull_geometry(
            session,
            args.geometry_service_root,
            target_pins,
            population_details,
            geometry_resolved,
            geometry_metadata,
            args,
            output_dir,
        )
        manifest["geometry"] = geometry_summary
        manifest["unresolved_geometry_optional_fields"] = [
            field for field in geometry_missing if field not in {"Parcel_ID", "OBJECTID"}
        ]
        write_json(output_dir / "pull_manifest.json", manifest)
        print("\nComplete.")
        print("Tax history:", tax_complete_path)
        print("Parcels:", output_dir / "single_family_parcels.geojson")
        print("Centroids:", output_dir / "single_family_centroids.csv")
        print("Manifest:", output_dir / "pull_manifest.json")
        return 0
    except Exception as exc:
        report = {
            "complete": False,
            "reason": "The pull failed before a complete snapshot was created.",
            "error": str(exc),
            "plan": plan,
        }
        write_json(output_dir / "pull_error_report.json", report)
        print(f"Pull failed: {exc}", file=sys.stderr)
        print("See:", output_dir / "pull_error_report.json", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
