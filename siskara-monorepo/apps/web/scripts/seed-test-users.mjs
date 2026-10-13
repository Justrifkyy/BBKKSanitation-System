import { mkdir, open, readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { cert, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const PROJECT_ID = "bbkk-9d446";
const DATABASE_ID = "bbkkmakassar";
const MIGRATION_ID = "002_test_users";
const PASSWORD_MIGRATION_ID = "003_test_user_passwords";
const EMAIL_DOMAIN = "example.com";
const TEST_PASSWORD = "password";
const CREDENTIALS_PATH = join(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  ".local",
  "test-users.credentials.json",
);

const roleSeeds = [
  {
    role: "validator_admin",
    label: "Admin",
    emailSlug: "admin",
    names: ["Admin SISKARA Testing"],
  },
  {
    role: "kepala_kapal",
    label: "Nahkoda",
    emailSlug: "nahkoda",
    names: ["Andi Saputra", "Budi Santoso", "Citra Pratama", "Dedi Kurniawan", "Eka Mahendra"],
  },
  {
    role: "kepala_penerbangan",
    label: "Pilot",
    emailSlug: "pilot",
    names: ["Fajar Nugraha", "Gilang Permana", "Hana Puspita", "Indra Wijaya", "Joko Firmansyah"],
  },
  {
    role: "staf_bbkk",
    label: "Petugas BBKK",
    emailSlug: "staf",
    names: ["Kiki Amalia", "Lukman Hakim", "Maya Lestari", "Nanda Putri", "Oki Ramadhan"],
  },
];

function parseArguments(args) {
  const options = {
    apply: false,
    confirmProduction: false,
    project: null,
    database: null,
  };
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--apply") options.apply = true;
    else if (arg === "--confirm-production") options.confirmProduction = true;
    else if (arg === "--project") options.project = args[++index] ?? null;
    else if (arg.startsWith("--project=")) options.project = arg.slice(10);
    else if (arg === "--database") options.database = args[++index] ?? null;
    else if (arg.startsWith("--database=")) options.database = arg.slice(11);
    else throw new Error(`Unknown argument: ${arg}`);
  }
  if (!options.project) throw new Error("Pass an explicit --project <project-id>.");
  if (!options.database) throw new Error("Pass an explicit --database <database-id>.");
  return options;
}

function createSeedAccounts() {
  return roleSeeds.flatMap(({ role, label, emailSlug, names }, roleIndex) =>
    names.map((name, index) => {
      const number = String(index + 1).padStart(2, "0");
      const uid = `siskara-test-${emailSlug}-${number}`;
      return {
        uid,
        email: `siskara.${emailSlug}.${number}@${EMAIL_DOMAIN}`,
        name,
        phone: `+628000000${roleIndex + 1}${number}0`,
        role,
        displayRole: label,
        accountPassword: TEST_PASSWORD,
      };
    }),
  );
}

async function loadCredentials(accounts) {
  await mkdir(dirname(CREDENTIALS_PATH), { recursive: true });
  let credentialsFileExists = false;
  try {
    const existing = JSON.parse(await readFile(CREDENTIALS_PATH, "utf8"));
    if (
      existing.project_id !== PROJECT_ID ||
      existing.database_id !== DATABASE_ID ||
      !Array.isArray(existing.accounts) ||
      existing.accounts.length !== accounts.length
    ) {
      throw new Error(
        "Existing local seed credentials do not match the expected test account set.",
      );
    }
    const byUid = new Map(existing.accounts.map((account) => [account.uid, account]));
    for (const account of accounts) {
      const credential = byUid.get(account.uid);
      if (
        !credential ||
        credential.email !== account.email
      ) {
        throw new Error(
          "Existing local seed credentials are incomplete or do not match the expected accounts.",
        );
      }
    }
    credentialsFileExists = true;
  } catch (error) {
    if (error && typeof error === "object" && "code" in error && error.code === "ENOENT") {
      // The credentials file is created after validating its expected path.
    } else {
      throw error;
    }
  }

  for (const account of accounts) {
    account.accountPassword = TEST_PASSWORD;
  }
  const payload = {
    project_id: PROJECT_ID,
    database_id: DATABASE_ID,
    warning: "Shared test password; use only for testing. Do not commit this file.",
    accounts: accounts.map((account) => ({
      uid: account.uid,
      email: account.email,
      role: account.role,
      password: TEST_PASSWORD,
    })),
  };

  const handle = await open(
    CREDENTIALS_PATH,
    credentialsFileExists ? "w" : "wx",
    0o600,
  );
  try {
    await handle.writeFile(`${JSON.stringify(payload, null, 2)}\n`, "utf8");
  } catch (error) {
    await handle.close();
    throw error;
  }
  await handle.close();
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const isProduction =
    options.project === PROJECT_ID && options.database === DATABASE_ID;
  if (options.apply && isProduction && !options.confirmProduction) {
    throw new Error(
      "Refusing production test-user creation without --confirm-production.",
    );
  }
  if (options.apply && !isProduction) {
    throw new Error(
      "This test-user seed is scoped to the confirmed SISKARA project and database.",
    );
  }

  const accounts = createSeedAccounts();
  console.log(`${options.apply ? "APPLY" : "DRY RUN"} ${MIGRATION_ID}`);
  console.log(`Project: ${options.project}`);
  console.log(`Database: ${options.database}`);
  console.log(`Accounts: ${accounts.length}`);
  for (const { role, label, names } of roleSeeds) {
    console.log(`  ${label} (${role}): ${names.length}`);
  }
  if (!options.apply) {
    console.log("No credentials were generated and no Firebase writes were made.");
    return;
  }

  await import("dotenv/config");
  if (process.env.FIREBASE_PROJECT_ID !== options.project) {
    throw new Error(
      "FIREBASE_PROJECT_ID in apps/web/.env must match --project before seeding.",
    );
  }
  if ((process.env.FIRESTORE_DATABASE_ID || DATABASE_ID) !== options.database) {
    throw new Error(
      "FIRESTORE_DATABASE_ID in apps/web/.env must match --database before seeding.",
    );
  }
  if (!process.env.FIREBASE_CLIENT_EMAIL || !process.env.FIREBASE_PRIVATE_KEY) {
    throw new Error(
      "Configure FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY in the local, git-ignored apps/web/.env file.",
    );
  }
  await loadCredentials(accounts);

  const app = initializeApp({
    projectId: options.project,
    credential: cert({
      projectId: options.project,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
    }),
  });
  const auth = getAuth(app);
  const db = getFirestore(app, options.database);
  const migrationRef = db.collection("schema_migrations").doc(MIGRATION_ID);
  const passwordMigrationRef = db
    .collection("schema_migrations")
    .doc(PASSWORD_MIGRATION_ID);
  const migration = await migrationRef.get();
  if (migration.exists) {
    const passwordMigration = await passwordMigrationRef.get();
    if (!passwordMigration.exists) {
      const adminUid = accounts.find(
        (account) => account.role === "validator_admin",
      ).uid;

      for (const account of accounts) {
        const userRecord = await auth.getUser(account.uid);
        if (userRecord.email !== account.email) {
          throw new Error(
            `Seed UID ${account.uid} is already used by a different email account.`,
          );
        }
        if (
          userRecord.customClaims?.role !== undefined &&
          userRecord.customClaims.role !== account.role
        ) {
          throw new Error(
            `Firebase Auth account ${account.uid} already has a different role claim.`,
          );
        }
        const profile = await db.collection("users").doc(account.uid).get();
        if (!profile.exists || profile.data()?.role !== account.role) {
          throw new Error(
            `Firestore profile ${account.uid} is missing or has a different role.`,
          );
        }
      }

      const passwordBatch = db.batch();
      for (const account of accounts) {
        await auth.updateUser(account.uid, {
          password: account.accountPassword,
        });
        passwordBatch.set(db.collection("audit_log").doc(), {
          user_id: adminUid,
          aksi: "reset_test_user_password",
          entitas_terkait: `users/${account.uid}`,
          waktu: FieldValue.serverTimestamp(),
        });
      }
      passwordBatch.create(passwordMigrationRef, {
        migration_id: PASSWORD_MIGRATION_ID,
        description: "Set the shared test password for all seeded test accounts.",
        account_count: accounts.length,
        applied_at: FieldValue.serverTimestamp(),
      });
      await passwordBatch.commit();
      console.log(
        `Updated the shared test password for ${accounts.length} accounts.`,
      );
      console.log(`Local credentials saved to ${CREDENTIALS_PATH}`);
      return;
    }
    console.log(
      `Seed and test-password migrations already applied at ${migration.data()?.applied_at?.toDate?.().toISOString() ?? "an earlier time"}.`,
    );
    return;
  }

  for (const account of accounts) {
    try {
      const existingByUid = await auth.getUser(account.uid);
      if (existingByUid.email !== account.email) {
        throw new Error(
          `Seed UID ${account.uid} is already used by a different email account.`,
        );
      }
    } catch (error) {
      if (
        !(error && typeof error === "object" && "code" in error &&
          error.code === "auth/user-not-found")
      ) {
        throw error;
      }
      try {
        const existingByEmail = await auth.getUserByEmail(account.email);
        throw new Error(
          `Seed email ${account.email} is already attached to UID ${existingByEmail.uid}.`,
        );
      } catch (emailError) {
        if (
          !(emailError && typeof emailError === "object" &&
            "code" in emailError && emailError.code === "auth/user-not-found")
        ) {
          throw emailError;
        }
      }
    }

    const profile = await db.collection("users").doc(account.uid).get();
    if (profile.exists && profile.data()?.role !== account.role) {
      throw new Error(
        `Firestore profile ${account.uid} exists with a different role.`,
      );
    }
  }

  const adminUid = accounts.find(
    (account) => account.role === "validator_admin",
  ).uid;
  for (const account of accounts) {
    let userRecord;
    try {
      userRecord = await auth.getUser(account.uid);
    } catch (error) {
      if (
        !(error && typeof error === "object" && "code" in error &&
          error.code === "auth/user-not-found")
      ) {
        throw error;
      }
      userRecord = await auth.createUser({
        uid: account.uid,
        email: account.email,
        password: account.accountPassword,
        displayName: account.name,
        disabled: false,
      });
    }

    await auth.updateUser(userRecord.uid, {
      password: account.accountPassword,
    });
    const existingClaims = userRecord.customClaims ?? {};
    if (
      existingClaims.role !== undefined &&
      existingClaims.role !== account.role
    ) {
      throw new Error(
        `Firebase Auth account ${account.uid} already has a different role claim.`,
      );
    }
    await auth.setCustomUserClaims(userRecord.uid, {
      ...existingClaims,
      role: account.role,
    });
    console.log(`Prepared ${account.email} (${account.role}).`);
  }

  const batch = db.batch();
  for (const account of accounts) {
    const userRef = db.collection("users").doc(account.uid);
    const currentProfile = await userRef.get();
    const profileData = {
      nama: account.name,
      role: account.role,
      role_id: account.role,
      phone: account.phone,
      id_number: null,
      signature_url: null,
      has_pin: false,
      dibuat_oleh: account.uid === adminUid ? null : adminUid,
      ...(currentProfile.exists ? {} : { created_at: FieldValue.serverTimestamp() }),
    };
    batch.set(userRef, profileData, { merge: true });
    batch.set(db.collection("audit_log").doc(), {
      user_id: adminUid,
      aksi: "seed_test_user",
      entitas_terkait: `users/${account.uid}`,
      waktu: FieldValue.serverTimestamp(),
    });
  }
  batch.create(migrationRef, {
    migration_id: MIGRATION_ID,
    description: "Create one admin and five test accounts per mobile role.",
    account_count: accounts.length,
    applied_at: FieldValue.serverTimestamp(),
  });
  batch.create(passwordMigrationRef, {
    migration_id: PASSWORD_MIGRATION_ID,
    description: "Set the shared test password for all seeded test accounts.",
    account_count: accounts.length,
    applied_at: FieldValue.serverTimestamp(),
  });
  await batch.commit();

  console.log("Test accounts created/verified and migration marker recorded.");
  console.log("Firebase Authentication applies its password hashing internally.");
  console.log(`Local credentials saved to ${CREDENTIALS_PATH}`);
  console.log("The credentials file is ignored by Git; do not commit or share it.");
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
