---
name: permissions-gated-diff
description: Prepare review-only diffs for Camera, Bluetooth and HealthKit Usage Descriptions and Entitlements. Production has priority. Never edit project.yml or Info.plist directly.
---

# Permissions Gated Diff

## Rules
- Current Studio project.yml, Info.plist and entitlements lack camera, Bluetooth and Health declarations.
- "Just wire the publisher" is incomplete. Propose a minimal gated review-diff.
- Existing Founder gates for project.yml and workflows must be respected.
- Production camera ownership takes precedence over bio sources.
- Denial and revocation must leave observable, non-crashing states and stop capture.

See G-A platform matrix and FOUNDER_PRODUCT_LAW.
