# Product Vision

## Problem

Digital services, APIs, and critical endpoints are used daily by people and organizations, and their unavailability or degradation can directly affect applications and processes that depend on them.

There is not always a centralized, easy-to-understand source that allows users to follow service availability, analyze operating history, identify changes in response time, and compare automated monitoring with reports from other users.

PulseBeam aims to address this problem through a centralized monitoring platform capable of continuously tracking services and endpoints, preserving their operational history, and providing indicators that make current status and long-term reliability easier to understand.

## Product vision

PulseBeam is a collaborative monitoring platform for the availability and health of digital services.

It is divided into two main experiences:

### PulseBeam Community

A public area for relevant digital services used by many people. Public service pages may include automated status, uptime, average latency, historical charts, health score, incidents, community reports, comments, and followers.

### My PulseBeam

A private area where authenticated users can monitor their own endpoints and systems without publishing them to the community. Private services keep their monitoring data, metrics, incidents, and alerts restricted to authorized users.

Both experiences share the same Monitoring Engine.

## General objective

Develop a collaborative platform using Gleam and the BEAM ecosystem to continuously monitor the availability and performance of digital services, APIs, and endpoints, allowing users to follow operational history, health indicators, and community-reported incidents.

## Specific objectives

- Periodically monitor registered services and endpoints.
- Record HTTP response codes and response times.
- Maintain a history of checks.
- Present availability and performance through charts and metrics.
- Calculate availability over relevant periods.
- Define a Health Score between 0 and 100 based on objective monitoring data.
- Allow authenticated users to maintain private endpoints in My PulseBeam.
- Maintain a curated public Community catalog.
- Allow users to favorite public services and receive alerts about incidents.
- Allow authenticated users to report possible failures and comment on public services.
- Keep automated monitoring separate from community perception.

## In scope for v1.0

- HTTP service monitoring.
- Concurrent checks.
- Scheduling.
- Check history.
- Uptime and latency metrics.
- Health Score.
- Web/API access to monitoring data.
- Authentication.
- Private user endpoints.
- Public Community services.
- Favorites and incident notifications.
- Community reports and comments.
- Basic administration and moderation.

## Out of scope for v1.0

- Vulnerability scanning.
- CVE detection.
- Penetration testing.
- Exploit detection.
- Advanced TLS/security auditing.
- Infrastructure agents.
- CPU/RAM monitoring.
- Mobile applications.
- Advanced synthetic browser monitoring.

Security and vulnerability monitoring may be evaluated in a future major phase after the availability-monitoring product is stable.
