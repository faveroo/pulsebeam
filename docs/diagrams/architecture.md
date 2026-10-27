# Component Architecture

This diagram captures responsibility boundaries rather than a frozen folder structure.

```mermaid
flowchart TB
    subgraph Interfaces
      CLI[CLI]
      API[HTTP API - future]
      Web[Web UI - future]
    end

    subgraph Application
      ServiceUC[Service Use Cases]
      MonitoringUC[Monitoring Use Cases]
      MetricsUC[Metrics Use Cases]
      CommunityUC[Community Use Cases]
    end

    subgraph Domain
      Service[Service]
      Check[ServiceCheck]
      Incident[Incident]
      Metrics[Uptime / Health Score]
      Community[Favorite / Report / Comment]
    end

    subgraph Infrastructure
      Scheduler[Scheduler / BEAM Processes]
      Http[HTTP Client]
      Persistence[Persistence Adapter]
      Notifications[Notification Adapter - future]
      Clock[Clock / Timer]
    end

    CLI --> ServiceUC
    CLI --> MonitoringUC
    API --> ServiceUC
    API --> MonitoringUC
    API --> MetricsUC
    API --> CommunityUC
    Web --> API

    ServiceUC --> Service
    MonitoringUC --> Service
    MonitoringUC --> Check
    MonitoringUC --> Incident
    MetricsUC --> Metrics
    MetricsUC --> Check
    CommunityUC --> Community
    CommunityUC --> Service

    MonitoringUC --> Scheduler
    MonitoringUC --> Http
    MonitoringUC --> Persistence
    MonitoringUC --> Clock
    ServiceUC --> Persistence
    MetricsUC --> Persistence
    CommunityUC --> Persistence
    Incident --> Notifications
```

## Boundary rules

- Domain rules must not depend directly on the HTTP client or persistence engine.
- Monitoring behavior is shared by Community and Private services.
- Public/private authorization and presentation rules must not be embedded inside the low-level monitoring worker.
- Infrastructure adapters may change without rewriting core classification and metric rules.
- The architecture should start simple; additional layers should only become concrete modules when behavior justifies them.
