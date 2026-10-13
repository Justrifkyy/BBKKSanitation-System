import { verifyAuth } from "@/lib/auth";
import { isValidPin, verifyUserPin } from "@/lib/pin";
import { adminDb } from "@/lib/firebase-admin";
import { COLLECTIONS, SUBMISSION_STATUS } from "@/lib/constants";
import {
  evaluateSubmissionAnswers,
  SubmissionValidationError,
} from "@/lib/submission-evaluation";
import { NextRequest, NextResponse } from "next/server";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id: submissionId } = await params;
  const authResult = await verifyAuth(request, ["kepala_kapal", "kepala_penerbangan"]);
  if ("error" in authResult) return authResult.error;

  const body = (await request.json()) as { pin?: unknown };
  if (!isValidPin(body.pin)) {
    return NextResponse.json({ error: "PIN harus terdiri dari 6 angka." }, { status: 400 });
  }

  const pinCheck = await verifyUserPin(authResult.user.uid, body.pin);
  if (!pinCheck.valid) {
    return NextResponse.json(
      {
        error: pinCheck.locked
          ? "PIN dikunci selama 15 menit setelah 5 percobaan yang salah."
          : "PIN tidak sesuai.",
      },
      { status: pinCheck.locked ? 429 : 403 },
    );
  }

  const submissionRef = adminDb.collection(COLLECTIONS.SUBMISSIONS).doc(submissionId);
  const submission = await submissionRef.get();
  if (!submission.exists) {
    return NextResponse.json({ error: "Pengajuan tidak ditemukan." }, { status: 404 });
  }

  const data = submission.data()!;
  if (data.pengisi_id !== authResult.user.uid) {
    return NextResponse.json({ error: "Pengajuan ini bukan milik akun Anda." }, { status: 403 });
  }
  const expectedMode =
    authResult.user.role === "kepala_kapal" ? "kapal" : "pesawat";
  if (data.moda_transportasi !== expectedMode) {
    return NextResponse.json(
      { error: "Moda transportasi tidak sesuai dengan role akun Anda." },
      { status: 403 },
    );
  }
  if (data.status !== SUBMISSION_STATUS.DRAFT) {
    return NextResponse.json({ error: "Pengajuan tidak lagi berstatus draft." }, { status: 409 });
  }
  const requiredFields =
    expectedMode === "kapal"
      ? [
          "nama_kapal",
          "jenis_kapal",
          "besar_kapal_grt",
          "bendera",
          "nomor_imo",
          "pelabuhan_asal",
          "nama_pemilik_agen",
          "tanggal_jam_tiba",
          "diperiksa_tanggal_jam",
          "lokasi_sandar",
          "jumlah_awak_kapal",
        ]
      : [
          "pemilik_atau_penyelenggara",
          "nomor_penerbangan",
          "tanda_kebangsaan_dan_pendaftaran",
          "tanggal_jam",
          "berangkat_dari",
          "tujuan",
        ];
  const generalData =
    typeof data.data_umum === "object" && data.data_umum !== null
      ? data.data_umum as Record<string, unknown>
      : {};
  const missingField = requiredFields.find((field) => {
    const value = generalData[field];
    return value === null || value === undefined || String(value).trim() === "";
  });
  if (missingField) {
    return NextResponse.json(
      { error: `Data umum wajib diisi: ${missingField.replaceAll("_", " ")}.` },
      { status: 400 },
    );
  }

  const signature = await adminDb
    .collection(COLLECTIONS.USERS)
    .doc(authResult.user.uid)
    .get();
  if (!signature.data()?.signature_url) {
    return NextResponse.json(
      { error: "Tanda tangan digital belum disiapkan." },
      { status: 409 },
    );
  }

  const signatureRef = adminDb
    .collection(COLLECTIONS.DOCUMENT_SIGNATURES)
    .doc(`${submissionId}_declarant`);
  let evaluation: Awaited<ReturnType<typeof evaluateSubmissionAnswers>>;
  try {
    evaluation = await evaluateSubmissionAnswers(submissionRef);
  } catch (error) {
    if (error instanceof SubmissionValidationError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }
    throw error;
  }

  await adminDb.runTransaction(async (transaction) => {
    const current = await transaction.get(submissionRef);
    const existingSignature = await transaction.get(signatureRef);
    if (!current.exists || current.data()?.status !== SUBMISSION_STATUS.DRAFT) {
      throw new Error("Pengajuan sudah berubah dan tidak dapat ditandatangani.");
    }
    if (!existingSignature.exists) {
      transaction.create(signatureRef, {
        submission_id: submissionId,
        user_id: authResult.user.uid,
        role_saat_ttd: "pengisi",
        waktu_ttd: new Date(),
      });
    }
    transaction.update(submissionRef, {
      status: evaluation.status,
      updated_at: new Date(),
    });
    transaction.set(adminDb.collection(COLLECTIONS.AUDIT_LOG).doc(), {
      user_id: authResult.user.uid,
      aksi: evaluation.hasAutoReject ? "auto_reject" : "pass_to_review",
      entitas_terkait: `submissions/${submissionId}`,
      waktu: new Date(),
    });
  });

  return NextResponse.json({ success: true, status: evaluation.status });
}
