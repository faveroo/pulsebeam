# Diagrams

This directory contains the diagrams produced during Stage 2 — Modeling.

## Available artifacts

- [Use-case diagram](./use-cases.md)
- [Domain/class diagram](./domain-model.md)
- [Entity-relationship diagram (ERD)](./erd.md)
- [Monitoring sequence diagram](./monitoring-sequence.md)
- [High-level component/architecture diagram](./architecture.md)
- [Main activity/flow diagrams](./flows.md)

The diagrams use Mermaid so they remain reviewable in Git and render directly on GitHub.

## Modeling principles

- Keep automated monitoring separate from Community perception.
- Share one Monitoring Engine across Community and Private services.
- Keep domain rules independent from infrastructure where practical.
- Avoid freezing persistence, web framework, scheduler topology, or Health Score formula before those decisions are required.
