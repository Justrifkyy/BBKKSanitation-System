import { cert, initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const PRODUCTION_PROJECT = "bbkk-9d446";
const PRODUCTION_DATABASE = "bbkkmakassar";
const MIGRATION_ID = "001_initial_roles_and_checklists";
const roles = [
  { id: "kepala_kapal", display_name: "Nahkoda", platform: "mobile" },
  { id: "kepala_penerbangan", display_name: "Pilot", platform: "mobile" },
  { id: "staf_bbkk", display_name: "Petugas BBKK", platform: "mobile" },
  { id: "validator_admin", display_name: "Administrator", platform: "web" },
];
const shipLocations = [
  "Dapur (Galley)",
  "Ruang Rakit Makanan (Pantry)",
  "Gudang (Storage)",
  "Palka/Cargo",
  "Ruang Tidur - ABK (Crew)",
  "Ruang Tidur - Perwira (Officer)",
  "Ruang Tidur - Penumpang (Passenger)",
  "Ruang Pemeriksaan (Examination room)",
  "Geladak (Deck)",
  "Air Minum (Portable Water)",
  "Limbah Cair (Sewage)",
  "Air Balas (Water Ballast)",
  "Limbah Medis Cair/Padat",
  "Air Tergenang/Permukaan (Standing Water)",
  "Ruang Mesin (Engine Room)",
  "Fasilitas Medik (Medical Facilities)",
  "Area Lainnya",
];

const item = (
  id,
  kategori,
  label,
  tipe_input,
  opsi_jawaban = [],
  extra = {},
) => ({
  id,
  kategori,
  label,
  tipe_input,
  opsi_jawaban,
  nilai_gagal: [],
  nilai_perlu_alasan: [],
  nilai_perlu_media: [],
  auto_reject_on_fail: false,
  requires_media_on_fail: false,
  wajib_diisi: true,
  wajib_jika: null,
  ...extra,
});

const shipItems = [
  ...shipLocations.map((location, index) =>
    item(
      `higiene_${String(index + 1).padStart(2, "0")}`,
      "B - Higiene Sanitasi",
      location,
      "binary",
      ["memenuhi_syarat", "tidak_memenuhi_syarat"],
      {
        nilai_gagal: ["tidak_memenuhi_syarat"],
        nilai_perlu_alasan: ["tidak_memenuhi_syarat"],
        nilai_perlu_media: ["tidak_memenuhi_syarat"],
        auto_reject_on_fail: true,
        requires_media_on_fail: true,
      },
    ),
  ),
  ...shipLocations.map((location, index) =>
    item(
      `vektor_${String(index + 1).padStart(2, "0")}`,
      "C - Vektor dan Binatang Penular",
      location,
      "binary",
      ["tidak_tampak_tanda", "tampak_tanda"],
      {
        nilai_gagal: ["tampak_tanda"],
        nilai_perlu_alasan: ["tampak_tanda"],
        nilai_perlu_media: ["tampak_tanda"],
        auto_reject_on_fail: true,
        requires_media_on_fail: true,
      },
    ),
  ),
];

const aircraftItems = [];
const aircraftSubItems = [
  {
    category: "1 - Kabin Penumpang",
    labels: ["Lantai", "Kursi", "Meja", "Asbak", "Kantong belakang kursi"],
  },
  {
    category: "2 - Kompartemen Toilet",
    labels: ["Lantai", "Alas duduk dan penutup", "Tempat sampah", "Tempat cuci tangan", "Kaca"],
  },
  {
    category: "3 - Tempat Penyimpanan Makanan (Galley)",
    labels: ["Lantai", "Alas tempat kerja", "Bak cuci", "Tempat sampah", "Ruang tempat kontainer"],
  },
];

for (const section of aircraftSubItems) {
  section.labels.forEach((label) => {
    aircraftItems.push(
      item(
        `pesawat_${aircraftItems.length + 1}`,
        section.category,
        label,
        "three_level",
        ["baik", "cukup", "kurang"],
        {
          nilai_gagal: ["kurang"],
          nilai_perlu_alasan: ["cukup", "kurang"],
          nilai_perlu_media: ["cukup", "kurang"],
          auto_reject_on_fail: true,
          requires_media_on_fail: true,
        },
      ),
    );
  });
}

const toiletTypeId = "pesawat_16";
aircraftItems.push(
  item(toiletTypeId, "4 - Pembuangan Kotoran Cair", "Tipe toilet", "binary", ["portable", "suitable"]),
  item("pesawat_17", "4 - Pembuangan Kotoran Cair", "Ditangani petugas khusus", "binary", ["ya", "tidak"], {
    nilai_gagal: ["tidak"],
    nilai_perlu_alasan: ["tidak"],
    nilai_perlu_media: ["tidak"],
    auto_reject_on_fail: true,
    requires_media_on_fail: true,
  }),
  item("pesawat_18", "4 - Pembuangan Kotoran Cair", "Diangkat dalam keadaan tertutup", "binary", ["ya", "tidak"], {
    nilai_gagal: ["tidak"],
    nilai_perlu_alasan: ["tidak"],
    nilai_perlu_media: ["tidak"],
    auto_reject_on_fail: true,
    requires_media_on_fail: true,
  }),
  item("pesawat_19", "4 - Pembuangan Kotoran Cair", "Tercecer waktu diangkat", "binary", ["ya", "tidak"], {
    nilai_gagal: ["ya"],
    nilai_perlu_alasan: ["ya"],
    nilai_perlu_media: ["ya"],
    auto_reject_on_fail: true,
    requires_media_on_fail: true,
  }),
  item("pesawat_20", "5 - Penanganan Penyediaan Air", "Ditangani petugas khusus", "binary", ["ya", "tidak"], {
    nilai_gagal: ["tidak"],
    nilai_perlu_alasan: ["tidak"],
    nilai_perlu_media: ["tidak"],
    auto_reject_on_fail: true,
    requires_media_on_fail: true,
  }),
  item("pesawat_21", "5 - Penanganan Penyediaan Air", "Sisa kadar chlorine (ppm)", "numeric"),
  item("pesawat_22", "5 - Penanganan Penyediaan Air", "Banyaknya contoh air", "numeric"),
  item("pesawat_23", "6 - Keadaan Makanan Secara Fisik", "Kondisi makanan", "binary", ["baik", "jelek"], {
    nilai_gagal: ["jelek"],
    nilai_perlu_alasan: ["jelek"],
    nilai_perlu_media: ["jelek"],
    auto_reject_on_fail: true,
    requires_media_on_fail: true,
  }),
);

const foodCondition = { item_id: "pesawat_23", nilai: "jelek" };
for (const [index, label] of [
  "Busuk",
  "Berlendir",
  "Berjamur",
  "Tercemar",
].entries()) {
  aircraftItems.push(
    item(`pesawat_${24 + index}`, "6 - Keadaan Makanan Secara Fisik", label, "binary", ["tidak", "ya"], {
      wajib_diisi: false,
      wajib_jika: foodCondition,
    }),
  );
}

aircraftItems.push(
  item("pesawat_28", "6 - Keadaan Makanan Secara Fisik", "Banyaknya contoh makanan", "numeric", [], {
    wajib_diisi: false,
    wajib_jika: foodCondition,
  }),
  item("pesawat_29", "6 - Keadaan Makanan Secara Fisik", "Jenis makanan", "text", [], {
    wajib_diisi: false,
    wajib_jika: foodCondition,
  }),
);

const pestIds = [];
for (const [index, pest] of ["Nyamuk", "Lalat", "Kecoak", "Tikus", "Lain-lain"].entries()) {
  const pestId = `pesawat_${30 + index}`;
  pestIds.push(pestId);
  aircraftItems.push(
    item(pestId, "7 - Binatang Pengganggu", pest, "binary", ["tidak", "ya"], {
      nilai_gagal: ["ya"],
      nilai_perlu_alasan: ["ya"],
      nilai_perlu_media: ["ya"],
      auto_reject_on_fail: true,
      requires_media_on_fail: true,
    }),
  );
}

const pestCondition = {
  any: pestIds.map((item_id) => ({ item_id, nilai: "ya" })),
};
aircraftItems.push(
  item("pesawat_35", "8 - Tindakan Pemberantasan Serangga", "Nama insektisida", "text", [], {
    wajib_diisi: false,
    wajib_jika: pestCondition,
  }),
  item("pesawat_36", "8 - Tindakan Pemberantasan Serangga", "Jumlah insektisida (gram)", "numeric", [], {
    wajib_diisi: false,
    wajib_jika: pestCondition,
  }),
  item("pesawat_37", "8 - Tindakan Pemberantasan Serangga", "Nomor tabung yang dipakai", "text", [], {
    wajib_diisi: false,
    wajib_jika: pestCondition,
  }),
);

const templates = [
  {
    id: "kapal-v1",
    moda_transportasi: "kapal",
    nama_template: "Pemeriksaan Higiene Sanitasi Kapal",
    versi: 1,
    is_active: true,
    reference_form: "Formulir Pemeriksaan Higiene Sanitasi Kapal (PMK RI No. 40 Tahun 2015)",
    items: shipItems,
  },
  {
    id: "pesawat-v1",
    moda_transportasi: "pesawat",
    nama_template: "Pemeriksaan Sanitasi Pesawat Udara",
    versi: 1,
    is_active: true,
    reference_form: "Formulir Pemeriksaan Sanitasi Pesawat Udara (BBKK)",
    items: aircraftItems,
  },
];

function validateTemplates() {
  const templateIds = new Set();
  const modes = new Set();

  for (const template of templates) {
    if (templateIds.has(template.id) || modes.has(template.moda_transportasi)) {
      throw new Error("Seed templates must have unique ids and transport modes.");
    }
    templateIds.add(template.id);
    modes.add(template.moda_transportasi);

    const itemIds = new Set(template.items.map(({ id }) => id));
    if (itemIds.size !== template.items.length) {
      throw new Error(`Template ${template.id} contains duplicate item ids.`);
    }
    for (const checklistItem of template.items) {
      const condition = checklistItem.wajib_jika;
      const dependencies = Array.isArray(condition?.any)
        ? condition.any
        : condition
          ? [condition]
          : [];
      for (const dependency of dependencies) {
        if (!itemIds.has(dependency.item_id)) {
          throw new Error(
            `Template item ${checklistItem.id} depends on missing item ${dependency.item_id}.`,
          );
        }
      }
      for (const field of ["nilai_gagal", "nilai_perlu_alasan", "nilai_perlu_media"]) {
        const values = checklistItem[field];
        if (
          checklistItem.opsi_jawaban.length > 0 &&
          values.some((value) => !checklistItem.opsi_jawaban.includes(value))
        ) {
          throw new Error(
            `Template item ${checklistItem.id} has ${field} values absent from its options.`,
          );
        }
      }
    }
  }
}

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

async function main() {
  validateTemplates();
  const options = parseArguments(process.argv.slice(2));
  const isProduction =
    options.project === PRODUCTION_PROJECT &&
    options.database === PRODUCTION_DATABASE;
  if (isProduction && options.apply && !options.confirmProduction) {
    throw new Error(
      `Refusing production writes. Review the target and add --confirm-production to proceed.`,
    );
  }

  console.log(`${options.apply ? "APPLY" : "DRY RUN"} Firestore migration ${MIGRATION_ID}`);
  console.log(`Project: ${options.project}`);
  console.log(`Database: ${options.database}`);
  console.log(`  ${roles.length} role records`);
  for (const template of templates) {
    console.log(
      `  ${template.id}: ${template.moda_transportasi}, ${template.items.length} checklist items`,
    );
  }

  if (!options.apply) {
    console.log("No database connection or writes were made. Add --apply to execute.");
    return;
  }

  await import("dotenv/config");
  if (process.env.FIREBASE_PROJECT_ID !== options.project) {
    throw new Error(
      "FIREBASE_PROJECT_ID in apps/web/.env must match --project before applying a migration.",
    );
  }
  if ((process.env.FIRESTORE_DATABASE_ID || "bbkkmakassar") !== options.database) {
    throw new Error(
      "FIRESTORE_DATABASE_ID must match --database before applying a migration.",
    );
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
  const migrationSnapshot = await migrationRef.get();
  if (migrationSnapshot.exists) {
    console.log(`Migration already applied at ${migrationSnapshot.data()?.applied_at}.`);
    return;
  }

  const [existingTemplates, existingRoles] = await Promise.all([
    db.collection("checklist_templates").limit(1).get(),
    db.collection("roles").limit(1).get(),
  ]);
  if (!existingTemplates.empty || !existingRoles.empty) {
    throw new Error(
      "The roles or checklist_templates collection is not empty. This baseline migration will not overwrite existing master data.",
    );
  }

  const batch = db.batch();
  for (const role of roles) {
    const { id, ...roleData } = role;
    batch.create(db.collection("roles").doc(id), roleData);
  }
  for (const template of templates) {
    const { items, ...templateData } = template;
    const templateRef = db.collection("checklist_templates").doc(template.id);
    batch.create(templateRef, {
      ...templateData,
      created_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    });
    for (const [index, checklistItem] of items.entries()) {
      const { id, ...itemData } = checklistItem;
      batch.create(templateRef.collection("items").doc(id), {
        ...itemData,
        template_id: template.id,
        order: index + 1,
      });
    }
  }
  batch.create(migrationRef, {
    migration_id: MIGRATION_ID,
    description: "Create the initial ship and aircraft sanitation checklist templates.",
    applied_at: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  console.log("Migration committed successfully.");
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
