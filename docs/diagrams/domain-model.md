# Domain Model

The domain model focuses on concepts and relationships, not database implementation details.

```mermaid
classDiagram
    class User {
      +id
      +name
      +email
      +role
    }

    class Service {
      +id
      +owner_id?
      +name
      +url
      +expected_status
      +check_interval
      +enabled
      +visibility
    }

    class ServiceCheck {
      +id
      +service_id
      +status
      +http_status?
      +latency_ms?
      +checked_at
      +error?
    }

    class Favorite {
      +user_id
      +service_id
      +created_at
    }

    class CommunityReport {
      +id
      +user_id
      +service_id
      +created_at
      +status
    }

    class Comment {
      +id
      +user_id
      +service_id
      +body
      +created_at
      +moderation_status
    }

    class Incident {
      +id
      +service_id
      +opened_at
      +resolved_at?
      +status
      +reason
    }

    class HealthSnapshot {
      +id
      +service_id
      +score
      +period_start
      +period_end
      +calculated_at
    }

    User "1" --> "0..*" Service : owns private
    Service "1" --> "0..*" ServiceCheck : has
    User "1" --> "0..*" Favorite : creates
    Service "1" --> "0..*" Favorite : followed by
    User "1" --> "0..*" CommunityReport : submits
    Service "1" --> "0..*" CommunityReport : receives
    User "1" --> "0..*" Comment : writes
    Service "1" --> "0..*" Comment : receives
    Service "1" --> "0..*" Incident : experiences
    Service "1" --> "0..*" HealthSnapshot : has
```

## Modeling notes

- `Service` is intentionally shared by Community and Private monitoring. Visibility and optional ownership distinguish the contexts.
- Community services may have no normal user owner and are curated administratively.
- `ServiceCheck` stores the monitoring outcome because the observed result is historical evidence, not only a value to derive later.
- `Favorite`, `CommunityReport`, and `Comment` only make sense for public Community services according to current requirements.
- `HealthSnapshot` is included as a conceptual historical metric. Whether scores are persisted or reconstructed remains an implementation decision.
- Incidents are separate from individual checks because an incident may span multiple consecutive failed checks and later be resolved.
