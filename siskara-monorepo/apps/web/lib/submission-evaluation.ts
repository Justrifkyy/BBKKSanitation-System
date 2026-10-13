import type { DocumentReference } from "firebase-admin/firestore";
import { COLLECTIONS, SUBMISSION_STATUS } from "@/lib/constants";

export class SubmissionValidationError extends Error {}

export async function evaluateSubmissionAnswers(
  submissionRef: DocumentReference,
): Promise<{ status: string; hasAutoReject: boolean }> {
  const submission = await submissionRef.get();
  if (!submission.exists) {
    throw new SubmissionValidationError("Pengajuan tidak ditemukan.");
  }
  const data = submission.data()!;
  if (data.status !== SUBMISSION_STATUS.DRAFT) {
    throw new SubmissionValidationError("Pengajuan tidak lagi berstatus draft.");
  }

  const templateRef = submissionRef.firestore
    .collection(COLLECTIONS.CHECKLIST_TEMPLATES)
    .doc(data.template_id);
  const [templateSnapshot, itemsSnapshot, answersSnapshot] = await Promise.all([
    templateRef.get(),
    templateRef
      .collection(COLLECTIONS.CHECKLIST_TEMPLATE_ITEMS)
      .orderBy("order")
      .get(),
    submissionRef
      .collection(COLLECTIONS.SUBMISSION_ANSWERS)
      .get(),
  ]);

  if (!templateSnapshot.exists) {
    throw new SubmissionValidationError("Template checklist tidak ditemukan.");
  }
  if (templateSnapshot.data()?.moda_transportasi !== data.moda_transportasi) {
    throw new SubmissionValidationError(
      "Moda transportasi tidak sesuai dengan template checklist.",
    );
  }
  if (itemsSnapshot.empty) {
    throw new SubmissionValidationError(
      "Template checklist belum memiliki butir pemeriksaan.",
    );
  }

  const answers = new Map(
    answersSnapshot.docs.map((answer) => [answer.data().template_item_id, answer]),
  );
  let hasAutoReject = false;

  for (const itemDoc of itemsSnapshot.docs) {
    const item = itemDoc.data();
    const answerDoc = answers.get(itemDoc.id);
    if (!answerDoc) {
      throw new SubmissionValidationError(
        `Butir checklist "${item.label || itemDoc.id}" belum dijawab.`,
      );
    }

    const answer = answerDoc.data();
    const value = answer.nilai_jawaban;
    if (value === null || value === undefined || String(value).trim() === "") {
      throw new SubmissionValidationError(
        `Jawaban untuk "${item.label || itemDoc.id}" belum diisi.`,
      );
    }

    const failValues = Array.isArray(item.nilai_gagal)
      ? item.nilai_gagal
      : item.nilai_gagal === undefined || item.nilai_gagal === null
        ? []
        : [item.nilai_gagal];
    const isFailure = failValues.some(
      (failValue: unknown) => String(failValue) === String(value),
    );

    if (isFailure) {
      if (typeof answer.alasan !== "string" || !answer.alasan.trim()) {
        throw new SubmissionValidationError(
          `Alasan wajib diisi untuk "${item.label || itemDoc.id}".`,
        );
      }

      const mediaSnapshot = await submissionRef
        .collection(COLLECTIONS.SUBMISSION_ANSWERS)
        .doc(answerDoc.id)
        .collection(COLLECTIONS.SUBMISSION_ANSWER_MEDIA)
        .limit(1)
        .get();
      if (mediaSnapshot.empty) {
        throw new SubmissionValidationError(
          `Bukti foto/video wajib dilampirkan untuk "${item.label || itemDoc.id}".`,
        );
      }

      if (item.auto_reject_on_fail === true) hasAutoReject = true;
    }
  }

  return {
    status: hasAutoReject
      ? SUBMISSION_STATUS.AUTO_REJECTED
      : SUBMISSION_STATUS.PENDING_REVIEW,
    hasAutoReject,
  };
}
