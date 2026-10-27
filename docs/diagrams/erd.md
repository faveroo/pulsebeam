# Entity Relationship Diagram

This ERD is an initial persistence-oriented translation of the current domain. It does not select a database technology.

```mermaid
erDiagram
    USERS ||--o{ SERVICES : owns
    USERS ||--o{ FAVORITES : creates
    USERS ||--o{ COMMUNITY_REPORTS : submits
    USERS ||--o{ COMMENTS : writes

    SERVICES ||--o{ SERVICE_CHECKS : has
    SERVICES ||--o{ FAVORITES : receives
    SERVICES ||--o{ COMMUNITY_REPORTS : receives
    SERVICES ||--o{ COMMENTS : receives
    SERVICES ||--o{ INCIDENTS : has
    SERVICES ||--o{ HEALTH_SNAPSHOTS : has

    USERS {
      uuid id PK
      string name
      string email UK
      string role
      datetime created_at
      datetime updated_at
    }

    SERVICES {
      uuid id PK
      uuid owner_id FK "nullable for Community"
      string name
      string url
      int expected_status
      int check_interval_seconds
      boolean enabled
      string visibility
      datetime created_at
      datetime updated_at
    }

    SERVICE_CHECKS {
      uuid id PK
      uuid service_id FK
      string status
      int http_status "nullable"
      int latency_ms "nullable"
      string error_type "nullable"
      string error_detail "nullable"
      datetime checked_at
    }

    FAVORITES {
      uuid id PK
      uuid user_id FK
      uuid service_id FK
      datetime created_at
    }

    COMMUNITY_REPORTS {
      uuid id PK
      uuid user_id FK
      uuid service_id FK
      string status
      datetime created_at
      datetime moderated_at "nullable"
    }

    COMMENTS {
      uuid id PK
      uuid user_id FK
      uuid service_id FK
      text body
      string moderation_status
      datetime created_at
      datetime updated_at
    }

    INCIDENTS {
      uuid id PK
      uuid service_id FK
      string status
      string reason
      datetime opened_at
      datetime resolved_at "nullable"
    }

    HEALTH_SNAPSHOTS {
      uuid id PK
      uuid service_id FK
      decimal score
      datetime period_start
      datetime period_end
      datetime calculated_at
    }
```

## Constraints to preserve later

- `USERS.email` should be unique.
- A user should not be able to favorite the same Community service twice; a unique `(user_id, service_id)` constraint is expected on `FAVORITES`.
- `SERVICES.owner_id` is nullable only because Community services can be platform-curated rather than personally owned.
- Private services must never be exposed through public queries.
- Exact ID types, column types, indexes, retention strategy, and persistence engine remain undecided.
