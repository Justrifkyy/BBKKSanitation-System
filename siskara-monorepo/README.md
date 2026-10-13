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

```bash
cd apps/mobile
flutter pub get
flutter run
```

### Web App (Next.js)

```bash
cd apps/web
npm install
npm run dev
```

### Firebase Rules

```bash
cd firebase
firebase deploy --only firestore:rules,storage
```

## Full Specification

See [`siskara_app_spec.json`](../siskara_app_spec.json) for the complete, ground-up specification.
