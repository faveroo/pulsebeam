# Monitoring Check Sequence

This sequence describes the core automated monitoring path without committing to a specific scheduler, HTTP library, or database implementation.

```mermaid
sequenceDiagram
    participant Scheduler
    participant Monitor as Monitoring Worker
    participant HTTP as HTTP Client
    participant External as External Service
    participant Classifier as Status Classifier
    participant Repo as Check Repository
    participant Incident as Incident Manager
    participant Metrics as Metrics Service

    Scheduler->>Monitor: trigger_check(service)
    Monitor->>HTTP: request(service.url, timeout)
    HTTP->>External: HTTP request

    alt Successful HTTP response
        External-->>HTTP: status + response
        HTTP-->>Monitor: response + latency
        Monitor->>Classifier: classify(expected, received)
        Classifier-->>Monitor: UP or DOWN(unexpected status)
    else Timeout / DNS / connection failure
        HTTP-->>Monitor: network error
        Monitor->>Classifier: classify(error)
        Classifier-->>Monitor: DOWN(error reason)
    end

    Monitor->>Repo: save ServiceCheck
    Repo-->>Monitor: stored
    Monitor->>Incident: evaluate state transition
    Incident-->>Monitor: incident opened/resolved/unchanged
    Monitor->>Metrics: update/recalculate derived metrics
    Metrics-->>Monitor: complete
```

## Design intent

- Network failures become domain results rather than crashing unrelated monitoring work.
- Classification is explicit and testable independently from the HTTP client.
- Persistence happens after the check result is constructed.
- Incident handling reacts to state transitions rather than equating one failed check with a complete incident policy.
- Metric calculation is downstream from historical monitoring data.
