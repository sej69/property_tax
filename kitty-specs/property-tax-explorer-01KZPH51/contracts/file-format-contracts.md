# Input and output contract

Parcel identifiers are treated as text and retain leading zeroes. Required
comparable fields are retained when present, including levy code, property
class, homestead, neighborhood, living area, value, year built, acreage,
bedrooms, bathrooms, stories, basement, building value, and land value.

Effective tax rate is `Total_Tax / Market_Value * 100` when market value is
positive. Invalid rows and duplicate parcel-year rows are rejected from the
published in-memory snapshot and counted in import diagnostics.

