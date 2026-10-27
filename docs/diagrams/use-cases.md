# Use Case Diagram

This diagram describes the main actors and product-level use cases currently planned for PulseBeam.

```mermaid
flowchart LR
    Visitor[Visitor]
    User[Authenticated User]
    Admin[Administrator]
    Engine[Monitoring Engine]

    subgraph PB[PulseBeam]
        UC1((View Community services))
        UC2((View public service status and metrics))
        UC3((Create private endpoint))
        UC4((Manage own private services))
        UC5((View private history and metrics))
        UC6((Favorite Community service))
        UC7((Receive incident alerts))
        UC8((Report possible failure))
        UC9((Comment on Community service))
        UC10((Manage Community catalog))
        UC11((Moderate reports and comments))
        UC12((Execute service check))
        UC13((Record latency and HTTP status))
        UC14((Classify UP or DOWN))
        UC15((Store check history))
        UC16((Calculate uptime and metrics))
        UC17((Detect service state transition))
        UC18((Create or resolve incident))
    end

    Visitor --> UC1
    Visitor --> UC2

    User --> UC1
    User --> UC2
    User --> UC3
    User --> UC4
    User --> UC5
    User --> UC6
    User --> UC7
    User --> UC8
    User --> UC9

    Admin --> UC10
    Admin --> UC11

    Engine --> UC12
    UC12 --> UC13
    UC13 --> UC14
    UC14 --> UC15
    UC15 --> UC16
    UC14 --> UC17
    UC17 --> UC18
```

## Actors

### Visitor

An unauthenticated person accessing the public PulseBeam Community catalog.

### Authenticated User

A registered user who can use Community features and manage private endpoints through My PulseBeam.

### Administrator

An authorized user responsible for curating the Community catalog and moderating public content.

### Monitoring Engine

An internal system actor responsible for scheduled checks, classification, historical monitoring data, metrics, and incident detection.

## Important distinction

The Monitoring Engine is modeled as a system actor to make responsibilities explicit. It is not a human user and must not be confused with Community reports. Automated technical monitoring and Community perception remain independent information sources.
