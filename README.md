# Sweissa Municipality — بلدية السويسة

Arabic Flutter application for resident services and municipal staff operations.

## Features

- Email OTP sign-in; optional SMS after provider setup.
- Resident issue reports and service requests with private photos and optional GPS.
- Persistent account-scoped drafts and retry-safe submissions.
- Paginated request tracking, staff notes, and status history.
- Department-scoped staff dashboard and real request statistics.
- Administrator-controlled staff roles, with role audit and last-admin protection.
- Published announcements, events, projects, waste schedules, and contact details.
- One-vote-per-account opinion polls with aggregate results and server-side closure.
- Real invoices and administrator-verified receipt recording.
- A map of the signed-in resident's own requests.
- Arabic layout, error/retry states, and refresh controls.

## Start

```powershell
flutter pub get
flutter run -d chrome
```

Apply the database migration and bootstrap a verified administrator before using
the new backend features. See [DEPLOYMENT.md](DEPLOYMENT.md) for the complete
setup, email OTP configuration, live acceptance checks, signing, and limitations.

## Structure

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | Startup, Arabic theme, navigation, service search |
| `lib/core/` | Repository, models, persistent drafts, shared UI states |
| `lib/pages/` | Resident and public-service screens |
| `lib/staff_dashboard_page.dart` | Protected staff and administrator tools |
| `supabase/migrations/` | Transactional schema upgrade and access controls |
| `supabase/tests/` | PostgreSQL permission and workflow tests |
| `test/` | Flutter draft, repository, role, submission, and layout tests |
| `.github/workflows/checks.yml` | Analysis, tests, web and Android test builds |

## Validation

```powershell
flutter analyze
flutter test
flutter build web --release
```

Database tests: `npm ci --ignore-scripts` and `npm test` from `supabase/tests`.

Online payments, OS push notifications, production hosting, and store signing
require external setup. Drafts are locally saved and retried manually; background
synchronization is not enabled. No demo data is represented as real municipal data.
