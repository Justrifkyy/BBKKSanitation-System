# SISKARA – Sistem Skrining dan Pemeriksaan Kesehatan Kapal dan Pesawat Udara

> **Client**: Balai Besar Kekarantinaan Kesehatan (BBKK) Makassar – Kementerian Kesehatan RI

## Overview

SISKARA digitizes BBKK's health quarantine inspection process for ships and aircraft. Ship/aircraft crew self-declare their sanitation condition through a mobile form, and BBKK staff review the declaration and give a final approve/reject decision. On approval, an official document (PHQC for ships, Berkas Verifikasi for aircraft) is generated automatically.

## Monorepo Structure

```
siskara-monorepo/
├── apps/
│   ├── mobile/        # Flutter (Dart) — Android & iOS
│   └── web/           # Next.js (App Router) — TypeScript + Tailwind CSS
├── firebase/          # Shared Firestore & Storage security rules
├── .github/workflows/ # CI/CD pipelines
└── README.md
```

## Tech Stack

| Layer    | Technology                         |
| -------- | ---------------------------------- |
| Mobile   | Flutter + Dart + Riverpod          |
| Web      | Next.js 14 (App Router) + TypeScript + Tailwind CSS |
| Backend  | Next.js API Routes (serverless)    |
| Services | Firebase (Auth, Firestore, Storage, FCM) |

## Roles

| Role                  | Platform | Description                                    |
| --------------------- | -------- | ---------------------------------------------- |
| `kepala_kapal`        | Mobile   | Ship captain — self-declares ship sanitation   |
| `kepala_penerbangan`  | Mobile   | Pilot — self-declares aircraft sanitation      |
| `staf_bbkk`           | Mobile   | BBKK staff — reviews & gives final decision    |
| `validator_admin`     | Web      | Admin — manages users, templates, exports data |

## Getting Started

### Prerequisites

- **Flutter SDK** ≥ 3.19
- **Node.js** ≥ 18
- **Firebase CLI** (`npm install -g firebase-tools`)

### Mobile App (Flutter)

The Android/iOS runner projects and Firebase configuration must be generated
before running the Flutter app:

```bash
cd apps/mobile
flutter create --platforms android,ios .
dart pub global activate flutterfire_cli
flutterfire configure
flutter pub get
flutter run --dart-define=SISKARA_API_BASE_URL=https://<your-web-host>/api
```

Add camera, microphone, and location permission descriptions to the generated
Android/iOS projects before testing evidence capture. Configure Firebase Admin
credentials for the web API and deploy the rules below. Registration, PIN,
signatures, and review decisions are handled by authenticated server routes.
The Firebase project uses the named Firestore database `bbkkmakassar` in
`asia-southeast2`; the web and mobile clients are configured to use that
database rather than `(default)`.

### Web App (Next.js)

```bash
cd apps/web
Copy-Item .env.example .env
npm install
npm run dev
```

### Firebase Rules

Firestore is schemaless: SQL-style tables are collections and subcollections,
and foreign keys are stored as document IDs. The versioned, forward-only
baseline migration seeds the `roles` collection and the two version-1
checklist templates (34 ship items, 37 aircraft items), then records its
completion in `schema_migrations`. Transaction collections such as `users`,
`submissions`, and `audit_log` gain documents as the app uses them; they do
not need empty placeholder documents. The migration refuses to overwrite
existing master data. Always dry-run first and test against an emulator or
staging project.

The web app connects to Firestore database `bbkkmakassar`. Configure its
project and database IDs in `.env`; the migration reads Firebase Admin
service-account credentials from this git-ignored local file. Firebase CLI
login is used separately to deploy rules and indexes. Never commit service
account keys.

Private signatures, evidence photos/videos, and future generated documents use
a private Cloudflare R2 bucket, not Firestore or Firebase Storage. Firestore
stores only protected object paths and media metadata. Configure the R2
account ID, bucket name, and a bucket-scoped access key in local `.env` and
the web deployment secrets. Mobile uploads use short-lived, authenticated
presigned URLs; API routes verify upload ownership and provide short-lived
download URLs only to the submitter and authorized BBKK staff/admin. Do not
enable public bucket access.

Cloudflare R2 currently includes monthly free-tier quotas for Standard storage
(10 GB-month), Class A operations (1 million), Class B operations (10 million),
and free egress. Usage beyond included quotas can incur charges. See
[Cloudflare R2 pricing](https://developers.cloudflare.com/r2/pricing/).

```bash
# Dry-run (does not connect to or write to Firebase)
npm --prefix apps/web run db:migrate -- --project demo-siskara --database bbkkmakassar

# Preview the testing-account seed
npm --prefix apps/web run db:seed-test-users -- --project bbkk-9d446 --database bbkkmakassar

# Preview and apply the master-data schema migration
npm --prefix apps/web run db:migrate-master-data -- --project bbkk-9d446 --database bbkkmakassar
npm --prefix apps/web run db:migrate-master-data -- --project bbkk-9d446 --database bbkkmakassar --apply --confirm-production

# Apply against the local Firestore emulator
firebase emulators:exec --project demo-siskara --only firestore \
  "npm --prefix apps/web run db:migrate -- --project demo-siskara --database bbkkmakassar --apply"

# Deploy Firestore indexes and rules only after verifying the target project
firebase deploy --only firestore:rules,firestore:indexes \
  --project <your-firebase-project-id>
```

For the production Firebase project `bbkk-9d446`, the initial data migration
requires the additional `--confirm-production` flag. Target database
`bbkkmakassar` explicitly. The initial migration has been applied to production
and verified: four role records, two active templates, and 71 checklist item
documents. Firestore rules and indexes are deployed separately from data
migrations. Firestore stores the R2 object path in `signature_url` and
`file_url`; private access is mediated by the authenticated API. PIN hashes
remain in the server-only `user_security` collection rather than the readable
user profile documents.

For test accounts, run `npm run db:seed-test-users -- --project bbkk-9d446
--database bbkkmakassar --apply --confirm-production` from `apps/web`. It
creates one `validator_admin` and five users for each mobile role, with
deterministic test emails and UIDs. All test accounts use the shared password
`password`; Firebase Authentication receives it as plaintext over its Admin
SDK and handles password hashing internally. This weak password is for
testing only. The ignored local file
`apps/web/.local/test-users.credentials.json` lists the account details; do
not commit or share it. The seed is idempotent and refuses to overwrite an
existing account with a different role or email. Test accounts are created in
Firebase Auth as well as Firestore and must be deleted from both when no
longer needed.

The web Admin portal includes read-only submission browsing and details, user
account creation/profile updates/deactivation, versioned checklist-template
management, generated-document browsing, filtered CSV/XLSX/PDF exports, and
audit-log viewing. Protected APIs verify Firebase ID tokens and server-side
roles; Admin pages do not include a submission approval/rejection action.
Checklist versions already referenced by submissions cannot have their items
replaced; create a new version instead.

Migration `003_master_data` records the versioned schemas for `master_ships`,
`master_aircraft`, and `master_locations`. It intentionally inserts no
placeholder records; Admins manage real reference data in the Data Master
portal. These reference collections are writable only through audited Admin
API routes. Existing submissions keep their `data_umum` snapshots, so later
master-record edits do not alter historical declarations. Final PDF
generation still needs the approved official PHQC and aircraft form layouts
and a private R2 bucket; the portal lists/downloads generated PDF records and
does not fabricate official forms or stamps.

Checklist items support `nilai_gagal`, `nilai_perlu_alasan`,
`nilai_perlu_media`, `wajib_diisi`, and conditional `wajib_jika` rules; these
keep soft findings distinct from automatic rejection and support conditional
aircraft form fields. Accounts and PIN security records are provisioned by
trusted API routes, not by client-side database writes.

The mobile app supports `kepala_kapal`, `kepala_penerbangan`, and
`staf_bbkk`; `validator_admin` uses the web portal.

## Full Specification

See [`siskara_app_spec.json`](../siskara_app_spec.json) for the complete, ground-up specification.
