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
  const itemIds = new Set(itemsSnapshot.docs.map((item) => item.id));
  for (const answer of answersSnapshot.docs) {
    if (!itemIds.has(answer.data().template_item_id)) {
      throw new SubmissionValidationError(
        "Pengajuan memuat jawaban yang tidak ada pada template.",
      );
    }
  }
  let hasAutoReject = false;

  for (const itemDoc of itemsSnapshot.docs) {
    const item = itemDoc.data();
    const answerDoc = answers.get(itemDoc.id);
    const requiredCondition = item.wajib_jika as Record<string, unknown> | undefined;
    const conditionMatches = (condition: unknown) => {
      if (typeof condition !== "object" || condition === null) return false;
      const entry = condition as { item_id?: unknown; nilai?: unknown };
      return (
        typeof entry.item_id === "string" &&
        answers.get(entry.item_id)?.data().nilai_jawaban === entry.nilai
      );
    };
    const anyConditions = requiredCondition?.any;
    const requiredByCondition = Array.isArray(anyConditions)
      ? anyConditions.some(conditionMatches)
      : conditionMatches(requiredCondition);
    const isRequired = item.wajib_diisi !== false || requiredByCondition;
    if (!answerDoc) {
      if (isRequired) {
        throw new SubmissionValidationError(
          `Butir checklist "${item.label || itemDoc.id}" belum dijawab.`,
        );
      }
      continue;
    }

    const answer = answerDoc.data();
    const value = answer.nilai_jawaban;
    if (value === null || value === undefined || String(value).trim() === "") {
      if (!isRequired) continue;
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
    const reasonValues = Array.isArray(item.nilai_perlu_alasan)
      ? item.nilai_perlu_alasan
      : item.nilai_perlu_alasan === undefined || item.nilai_perlu_alasan === null
        ? isFailure
          ? failValues
          : []
        : [item.nilai_perlu_alasan];
    const mediaValues = Array.isArray(item.nilai_perlu_media)
      ? item.nilai_perlu_media
      : item.nilai_perlu_media === undefined || item.nilai_perlu_media === null
        ? isFailure
          ? failValues
          : []
        : [item.nilai_perlu_media];

    if (reasonValues.some((requiredValue: unknown) => String(requiredValue) === String(value))) {
      if (typeof answer.alasan !== "string" || !answer.alasan.trim()) {
        throw new SubmissionValidationError(
          `Alasan wajib diisi untuk "${item.label || itemDoc.id}".`,
        );
      }
    }

    if (mediaValues.some((requiredValue: unknown) => String(requiredValue) === String(value))) {
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

    }
    if (isFailure && item.auto_reject_on_fail === true) hasAutoReject = true;
  }

  return {
    status: hasAutoReject
      ? SUBMISSION_STATUS.AUTO_REJECTED
      : SUBMISSION_STATUS.PENDING_REVIEW,
    hasAutoReject,
  };
}
