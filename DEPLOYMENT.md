# Deployment and acceptance

## Current scope

Arabic Flutter app for residents and staff. Supabase is the backend. All public
municipal facts are administrator-entered, with empty states before publication.
There are no sample requests, fabricated invoices, or automatic payment claims.

## Database deployment

1. Confirm project `kmppdktxrxvmglmfvcld` is the intended municipality project.
2. Back up existing database records. Check existing policies, especially Storage:
   PostgreSQL permissive policies combine with OR, so an unrelated broad policy
   must not accidentally expose the new bucket or private tables.
3. Apply `supabase/migrations/202610040001_municipality.sql` **once** using the
   migration system or SQL Editor. It upgrades the existing requests table without
   deleting records. `supabase/schema.sql` contains the same migration for a fresh
   install; do not execute both. The migration is transactional and intentionally
   fails if already-applied objects exist rather than overwriting live state.
4. Sign in as the verified administrator. Copy the account UUID from Account.
5. Replace the placeholder in `supabase/bootstrap_admin.sql`, then run it once.
6. Use Staff dashboard to assign employees to departments and publish verified
   contact information, collection times, announcements, projects, and events.
7. Run the live acceptance flow below with separate resident and staff accounts.

## Authentication

- Enable email authentication. Configure the email OTP template to include
  `{{ .Token }}`; the app verifies the code, rather than consuming a magic link.
- Use an SMTP sender controlled by the municipality for public operation.
- Configure permitted site URLs and email rate limits for the actual web domain.
- SMS is disabled by default. Enable a supported SMS provider and test delivery
  before building with `--dart-define=ENABLE_SMS_AUTH=true`.
- Never put service_role, database passwords, SMTP secrets, or payment secrets
  in Flutter configuration. The committed Supabase key is a public client key.
- Accounts are not proof of village residency. Any restricted official service
  needs a municipality-approved identity verification process before launch.

## Run and build

Flutter 3.44.6 / Dart 3.12.2 is the tested baseline. Android uses Java 21.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
flutter build web --release
flutter build apk --debug
```

The web build is `build/web`; serve it over HTTPS so browser geolocation works.
For a subdirectory deployment set `--base-href=/your-path/`. Authentication uses
codes, so it does not depend on a Flutter deep-link route. The repository CI
creates web and Android test APK artifacts and runs database policy tests.
The test APK uses Android's debug signing identity and is for testing.

For store releases, create a municipality-controlled signing key outside git and
configure `android/key.properties` using `android/key.properties.example`.
Build with `flutter build appbundle --release`. Release builds fail if that file
is missing, so debug keys cannot accidentally become a store release.
iOS builds require macOS, Xcode, signing, and physical-device testing.

The default key/project can be overridden for development without source edits:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_KEY
```

## Maps

The default map displays a resident's own submitted coordinates using
OpenStreetMap, with attribution and an identified mobile user agent. There is no
background tracking and no public resident map. For public scale, select a tile
provider with appropriate capacity and usage terms; override `MAP_TILE_URL` and
`MAP_ATTRIBUTION`. The map includes up to the latest 3,000 requests; request lists
are paginated without that cap. It is not an offline map download feature.

## Offline behavior

One issue-report draft and one service-request draft per account persist locally,
including an optional photo up to 1.5 MB. Drafts are not automatically sent or queued in the
background. Save, reconnect, and retry from the form. A stable request UUID avoids
duplicating a committed submission when the network response was lost. A content fingerprint rejects a changed draft that reuses an already-submitted request ID rather than claiming the changes were saved. Drafts
remain on a shared device after logout until explicitly deleted. Local browser
storage can be cleared by the browser and is not a secure archival system.

Uploaded photos use a private bucket and signed links valid for five minutes.
An upload interrupted before request insertion may leave an unlinked photo.
Add an administrator maintenance job to remove old unlinked storage objects
through the Storage API; do not delete live request photos or manipulate storage
metadata directly. Configure retention and account-deletion handling, including
deleting photo objects when removing an account; deleting database rows alone
does not delete stored files.

## Payments and notifications

Invoices are issued by administrators and can only be marked paid through an
administrator RPC that records the receipt, verifier, and timestamp. Actual
Whish/online payments require a merchant account, a backend integration, and
verified webhooks; online checkout is intentionally unavailable until connected.
Updates are visible in the app and can be refreshed. OS push notifications and
scheduled waste reminders are not enabled; they require notification delivery
configuration. No screen pretends that a push message or payment was sent.

## Live acceptance flow

1. Resident A signs in, attaches a photo and optional GPS position, and submits.
   Confirm one database row and a private photo object, plus a receipt in the app.
2. Resident B cannot read A's request, history, invoice, or photo through either
   the app or direct authenticated API calls.
3. Staff in the routed department can read and update the request. Another
   department cannot. Staff cannot change their own role or reassign departments.
4. Resident A refreshes and sees the new status and note in request history.
5. Disconnect before submitting another request: no success receipt appears;
   reopen the form and confirm the draft and photo persist. Reconnect and retry.
6. A second administrator session reassigns a department and adds/removes staff;
   revoked permissions must fail at the database even on an already-open screen.
7. Publish and unpublish content; signed-out visitors see published items only.
8. Vote once, try again, and try after the close time. Only the first valid vote
   counts, and other voters' account identities remain private.
9. Issue a real test invoice, record a verified receipt, and confirm residents
   cannot mark invoices paid. Do not process real money during this test.
10. Test image selection, camera, GPS denial, browser HTTPS, and small-screen
    layouts on real Android and iOS devices before distribution.

## Operations before public launch

The municipality must approve its official contact details, privacy text, data
retention period, account deletion procedure, service eligibility, and response
responsibilities. Configure backups, restore testing, monitoring, upload quotas,
email abuse controls, and an escalation process for urgent issues. This app is
not an emergency dispatch service. Replace provisional launcher artwork with
approved municipality branding before a store listing.

## Security test harness

```bash
cd supabase/tests
npm ci --ignore-scripts
npm test
```

PGlite executes the actual migration, policies, grants, triggers, and functions
inside PostgreSQL WASM with small auth/storage stubs. It checks both the upgrade
path and account/department boundaries. It does not replace testing Supabase's
live authentication, Storage upload transport, email delivery, or hosting.
