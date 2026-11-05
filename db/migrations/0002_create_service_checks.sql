CREATE TABLE service_checks (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    service_id UUID NOT NULL
        REFERENCES services(id),

    checked_at TIMESTAMPTZ NOT NULL,

    status TEXT NOT NULL
        CHECK (status IN ('up', 'down')),

    http_status INTEGER
        CHECK (http_status BETWEEN 100 AND 599),

    latency_ms INTEGER
        CHECK (latency_ms >= 0),

    error_reason TEXT
        CHECK (
            error_reason IN (
                'timeout',
                'connection_failed',
                'invalid_request',
                'invalid_response'
            )
        ),

    CONSTRAINT service_checks_outcome_check
        CHECK (
            (http_status IS NOT NULL AND error_reason IS NULL)
            OR
            (http_status IS NULL AND error_reason IS NOT NULL)
        ),

    CONSTRAINT service_checks_failure_status_check
        CHECK (error_reason IS NULL OR status = 'down')
);

CREATE INDEX idx_service_checks_history
    ON service_checks (service_id, checked_at DESC, id DESC);