import { randomBytes, scrypt as scryptCallback, timingSafeEqual } from "node:crypto";
import { promisify } from "node:util";
import { adminDb } from "@/lib/firebase-admin";

const scrypt = promisify(scryptCallback);
const KEY_LENGTH = 64;

export function isValidPin(pin: unknown): pin is string {
  return typeof pin === "string" && /^\d{6}$/.test(pin);
}

export async function hashPin(pin: string): Promise<string> {
  const salt = randomBytes(16).toString("hex");
  const derivedKey = (await scrypt(pin, salt, KEY_LENGTH)) as Buffer;
  return `${salt}:${derivedKey.toString("hex")}`;
}

export async function verifyPin(pin: string, storedHash: unknown): Promise<boolean> {
  if (typeof storedHash !== "string") return false;

  const [salt, keyHex, ...extra] = storedHash.split(":");
  if (!salt || !keyHex || extra.length > 0 || !/^[a-f\d]+$/i.test(keyHex)) {
    return false;
  }

  const expected = Buffer.from(keyHex, "hex");
  if (expected.length !== KEY_LENGTH) return false;

  const actual = (await scrypt(pin, salt, KEY_LENGTH)) as Buffer;
  return timingSafeEqual(actual, expected);
}

export async function verifyUserPin(
  userId: string,
  pin: string,
): Promise<{ valid: boolean; locked: boolean }> {
  const securityRef = adminDb.collection("user_security").doc(userId);
  return adminDb.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(securityRef);
    const data = snapshot.data();
    if (!data) return { valid: false, locked: false };

    const lockedUntil =
      data.locked_until instanceof Date
        ? data.locked_until
        : data.locked_until?.toDate?.();
    if (lockedUntil instanceof Date && lockedUntil.getTime() > Date.now()) {
      return { valid: false, locked: true };
    }

    const valid = await verifyPin(pin, data.pin_hash);
    if (valid) {
      transaction.update(securityRef, {
        failed_attempts: 0,
        locked_until: null,
      });
      return { valid: true, locked: false };
    }

    const attempts = Number(data.failed_attempts ?? 0) + 1;
    const locked = attempts >= 5;
    transaction.update(securityRef, {
      failed_attempts: locked ? 0 : attempts,
      locked_until: locked ? new Date(Date.now() + 15 * 60 * 1000) : null,
    });
    return { valid: false, locked };
  });
}
