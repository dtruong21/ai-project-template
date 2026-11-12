# Privacy Policy — {{PROJECT_NAME}}

*Last updated: {{DATE}}*

This is a starter template. Customize it for your project's actual data practices. **Host the rendered version publicly** (GitHub Pages, Notion, your domain) and link it from `.env PRIVACY_URL` + the App Store listing.

---

## What we collect

- **Account data**: email (if you sign up with email), display name, profile handle.
- **App data**: the content you create in the app ({{describe the data your app stores, e.g. "habit entries, journal entries, schedules"}}).
- **Device data**: anonymous crash reports (via Sentry / Firebase Crashlytics, if enabled), app version, OS version. No advertising identifiers.

## What we don't collect

- We do not collect location.
- We do not collect contacts.
- We do not sell or share data with advertisers.
- We do not run third-party analytics SDKs beyond what's listed in this document.

## How we store it

- Data lives in Firebase (Google Cloud). Access is gated by Firebase Authentication.
- Every request to our servers is authenticated, and the server only returns data belonging to the signed-in account.
- Data is encrypted at rest by Firebase.

## How we use it

- To make the app work (sync your data across devices, restore on reinstall).
- To respond to support requests.
- To improve the app (anonymous crash + perf data, if enabled).

## Sharing

- We do not sell your data.
- We do not share your data with third parties except: Firebase (data hosting), Apple/Google (app distribution metadata), {{Sentry/PostHog if enabled — list each}}.
- If you use shared features in the app, the relevant data is visible to the user(s) you share with.

## Your rights

- **Export**: contact {{support email}} for a data export.
- **Delete**: Settings → Delete Account in the app deletes all your data within 24 hours.
- **Correct**: edit your data inside the app.

## Children

The app is not directed at children under 13. We do not knowingly collect data from children under 13.

## Changes

We will update this page when our practices change. The "Last updated" date at the top tracks revisions.

## Contact

{{support email}}
