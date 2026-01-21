# Firestore Database Schema

## `users` Collection
Stores user profile information and settings.
**Document ID:** User UID (Matches Firebase Authentication UID)

| Field | Type | Description |
| :--- | :--- | :--- |
| `preferredName` | String | The user's display name |
| `photoUrl` | String | URL to the user's profile picture |
| `pronouns` | String | User's preferred pronouns (e.g., "he/him", "she/her") |
| `birthYear` | Number | User's year of birth (e.g., 1995) |
| `location` | String | User's location string (e.g., "City, Country") |
| `activities` | Array<String> | List of selected activity types (e.g., `['cycling', 'running']`) |
| `activityLevel` | String | Self-selected activity level (e.g., "starting", "active") |
| `measurementSystem` | String | Unit preference: `"metric"` or `"imperial"` |
| `profileVisibility` | String | Privacy setting: `"public"`, `"community"`, or `"private"` |
| `activitySharing` | String | Sharing setting: `"everyone"`, `"followers"`, or `"only_me"` |
| `liveActivitySharing` | Boolean | Toggle for real-time location sharing feature |
| `notifications` | Map | User's notification preferences |
| ↳ `activityReminders` | Boolean | Toggle for activity reminders |
| ↳ `communityUpdates` | Boolean | Toggle for community news |
| ↳ `achievementCelebrations` | Boolean | Toggle for achievement alerts |

---

## `routes` Collection
Stores created routes and paths.
**Document ID:** Auto-generated UUID

| Field | Type | Description |
| :--- | :--- | :--- |
| `userId` | String | The UID of the user who created the route |
| `name` | String | The display name of the route |
| `createdAt` | Timestamp | Server timestamp of creation |
| `distanceKm` | Number | Total route distance in kilometers |
| `durationMinutes` | Number | Estimated duration in minutes |
| `elevation` | Number | Total elevation gain in meters |
| `routeType` | Number | Type of route: `0` (Loop), `1` (One Way), `2` (Out & Back) |
| `routePoints` | Array<Map> | High-resolution list of coordinates forming the path |
| ↳ `lat` | Number | Latitude of the point |
| ↳ `lng` | Number | Longitude of the point |
| `waypoints` | Array<Map> | Key user-selected stops/markers |
| ↳ `lat` | Number | Latitude of the waypoint |
| ↳ `lng` | Number | Longitude of the waypoint |
