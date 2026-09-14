# MoveLog

Personal iPhone sports and health app concept implemented with SwiftUI.

## Current scope

- Light Active Editorial visual system
- Home, activity, health, routes and learning tabs
- Demo route map and sleep/activity data
- Private GitHub sync entry point (UI only in this first slice)

## Next integration slices

The current source includes the first integration pass for all three areas:

- HealthKit sleep read authorization and recent sleep aggregation
- Core Location background route recording with local route persistence
- GitHub OAuth with PKCE and client-side AES-GCM backup upload

Before testing GitHub login, replace `GitHubOAuthClientID` in `FitnessApp/Info.plist` with the Client ID of a GitHub OAuth App configured with the callback `movelog://oauth/callback`.

## Next integration slices

1. HealthKit workout write-back and Apple Watch support
2. Route following with deviation alerts and offline behavior
3. Full backup manifest, recovery key flow and encrypted workout history

The app is intentionally local/demo-first until those integrations are wired and verified on a physical iPhone.
