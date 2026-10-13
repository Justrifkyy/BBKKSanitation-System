import { cert, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const PRODUCTION_PROJECT = "bbkk-9d446";
const PRODUCTION_DATABASE = "bbkkmakassar";
const MIGRATION_ID = "003_master_data";
const COLLECTION_SCHEMAS = {
  master_ships: {
    description: "Registered vessels referenced by ship sanitation submissions.",
    fields: [
      "nama_kapal",
      "jenis_kapal",
      "besar_kapal_grt",
      "bendera",
      "nomor_imo",
      "nama_pemilik_agen",
      "normalized_key",
      "is_active",
      "created_at",
      "updated_at",
      "dibuat_oleh",
      "diubah_oleh",
    ],
    unique_key: "IMO number when present; otherwise normalized ship name",
  },
  master_aircraft: {
    description: "Registered aircraft and operators referenced by flight inspections.",
    fields: [
      "pemilik_atau_penyelenggara",
      "tanda_kebangsaan_dan_pendaftaran",
      "normalized_key",
      "is_active",
      "created_at",
      "updated_at",
      "dibuat_oleh",
      "diubah_oleh",
    ],
    unique_key: "normalized aircraft registration",
  },
  master_locations: {
    description: "Ports, airports, and berth locations selectable on submissions.",
    fields: [
      "nama",
      "jenis",
      "kode",
      "normalized_key",
      "is_active",
      "created_at",
      "updated_at",
      "dibuat_oleh",
      "diubah_oleh",
    ],
    allowed_types: ["pelabuhan", "bandara", "lokasi_sandar"],
    unique_key: "location type and normalized name",
  },
};

function parseArguments(args) {
  const options = {
    apply: false,
    confirmProduction: false,
    project: null,
    database: null,
  };
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === "--apply") options.apply = true;
    else if (argument === "--confirm-production") options.confirmProduction = true;
    else if (argument === "--project") options.project = args[++index] ?? null;
    else if (argument.startsWith("--project=")) options.project = argument.slice(10);
    else if (argument === "--database") options.database = args[++index] ?? null;
    else if (argument.startsWith("--database=")) options.database = argument.slice(11);
    else throw new Error(`Unknown argument: ${argument}`);
  }
  if (!options.project) throw new Error("Pass an explicit --project <project-id>.");
  if (!options.database) throw new Error("Pass an explicit --database <database-id>.");
  return options;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const isProduction =
    options.project === PRODUCTION_PROJECT &&
    options.database === PRODUCTION_DATABASE;
  if (options.apply && isProduction && !options.confirmProduction) {
    throw new Error("Refusing production writes without --confirm-production.");
  }

  console.log(`${options.apply ? "APPLY" : "DRY RUN"} Firestore migration ${MIGRATION_ID}`);
  console.log(`Project: ${options.project}`);
  console.log(`Database: ${options.database}`);
  for (const [name, schema] of Object.entries(COLLECTION_SCHEMAS)) {
    console.log(`  ${name}: ${schema.description}`);
  }
  console.log("No master records are seeded; authorized Admins add real records in the portal.");
  if (!options.apply) {
    console.log("No database connection or writes were made. Add --apply to execute.");
    return;
  }

  await import("dotenv/config");
  if (process.env.FIREBASE_PROJECT_ID !== options.project) {
    throw new Error("FIREBASE_PROJECT_ID in apps/web/.env must match --project.");
  }
  if ((process.env.FIRESTORE_DATABASE_ID || "bbkkmakassar") !== options.database) {
    throw new Error("FIRESTORE_DATABASE_ID must match --database.");
  }
  if (!process.env.FIREBASE_CLIENT_EMAIL || !process.env.FIREBASE_PRIVATE_KEY) {
    throw new Error(
      "Set FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY in the local, git-ignored apps/web/.env file.",
    );
  }

  const app = initializeApp({
    projectId: options.project,
    credential: cert({
      projectId: options.project,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
    }),
  });
  const db = getFirestore(app, options.database);
  const migrationRef = db.collection("schema_migrations").doc(MIGRATION_ID);
  const existingMigration = await migrationRef.get();
  if (existingMigration.exists) {
    console.log(`Migration already applied at ${existingMigration.data()?.applied_at}.`);
    return;
  }

  await migrationRef.create({
    migration_id: MIGRATION_ID,
    description: "Register versioned schemas for ships, aircraft, and transport locations.",
    collections: COLLECTION_SCHEMAS,
    applied_at: FieldValue.serverTimestamp(),
  });
  console.log("Master-data schema migration recorded. Collections will receive documents when created in the Admin portal.");
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
