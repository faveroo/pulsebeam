CREATE TABLE services (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    expected_status INTEGER NOT NULL,
    interval_seconds INTEGER NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    visibility TEXT NOT NULL,
    CONSTRAINT services_expected_status_check
        CHECK (expected_status BETWEEN 100 AND 599),
    CONSTRAINT services_interval_seconds_check
        CHECK (interval_seconds > 0),
    CONSTRAINT services_visibility_check
        CHECK (visibility IN ('community', 'private'))
);