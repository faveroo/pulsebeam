# Main Flows

## Monitoring flow

```mermaid
flowchart TD
    A[Scheduled check starts] --> B{Service enabled?}
    B -- No --> Z[Skip check]
    B -- Yes --> C[Perform HTTP request]
    C --> D{Request outcome}
    D -- Expected status --> E[Create UP check]
    D -- Unexpected status --> F[Create DOWN check with status]
    D -- Timeout --> G[Create DOWN check with timeout]
    D -- DNS/connection error --> H[Create DOWN check with network error]
    E --> I[Persist check]
    F --> I
    G --> I
    H --> I
    I --> J[Evaluate previous vs current state]
    J --> K{State transition?}
    K -- UP to DOWN --> L[Evaluate/open incident]
    K -- DOWN to UP --> M[Resolve active incident if applicable]
    K -- No --> N[Keep incident state]
    L --> O[Update derived metrics]
    M --> O
    N --> O
```

## Private endpoint creation

```mermaid
flowchart TD
    A[Authenticated user] --> B[Submit endpoint configuration]
    B --> C[Validate name, URL, expected status and interval]
    C --> D{Valid?}
    D -- No --> E[Return validation errors]
    D -- Yes --> F[Create Service]
    F --> G[Set owner to current user]
    G --> H[Set visibility to Private]
    H --> I[Enable monitoring]
```

## Community report flow

```mermaid
flowchart TD
    A[Authenticated user] --> B[Open Community service]
    B --> C[Submit failure report]
    C --> D[Store CommunityReport]
    D --> E[Update recent report count]
    E --> F[Display Community signal]
    F --> G[Automated status remains independent]
```

## Favorite and alert flow

```mermaid
flowchart TD
    A[Authenticated user] --> B[Favorite Community service]
    B --> C[Store Favorite]
    C --> D[Monitoring Engine detects relevant incident]
    D --> E[Find followers]
    E --> F[Create notification event]
    F --> G[Deliver through configured channel]
```

## Modeling notes

- A single failed check does not yet define the final incident policy; thresholds and consecutive-failure rules remain open decisions.
- Community reports never overwrite automated status.
- Private services are private by default and tied to their authenticated owner.
- Notification channels are intentionally abstract because providers are outside the current milestone.
