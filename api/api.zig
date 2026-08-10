const ingest = @import("ingest");
const comparable = @import("comparable");

pub const Api = struct {
    pub const name = "property-tax-explorer-readonly-v1";
    pub const read_only = true;
    pub const upload_routes = false;
    pub const max_comparables = 20;

    pub fn compare(subject: *const ingest.Property, records: []const ingest.Property, candidates: []comparable.Candidate) comparable.Result {
        return comparable.find(subject, records, candidates);
    }
};
