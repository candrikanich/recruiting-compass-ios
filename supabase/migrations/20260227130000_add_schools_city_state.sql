-- Add city and state columns to schools table
-- Required for SchoolCreateRequest insert; iOS app sends these when adding a school.
-- The School model expects city and state at top level for display and AcademicInfo.

ALTER TABLE schools ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS state text;
