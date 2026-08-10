# Independent statistical model

The phase-two model is deliberately separate from direct comparables. It
produces a robust median baseline for the selected tax year and property class,
then reports the actual-minus-predicted residual. A production release can
replace this baseline with a robust regression or gradient-boosted model using
levy context, neighborhood, value, size, age, acreage, bedrooms, bathrooms,
and structure features. Tax rate remains the response, never a comparable
feature.
