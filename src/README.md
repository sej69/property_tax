# Source layout note

The Zig 0.16 build uses feature-owned top-level modules (`app/`, `ingest/`,
`provider/`, and related directories) so each package can be tested directly.
This directory is retained for Spec Kitty's standard software-delivery layout
and future shared source modules.
