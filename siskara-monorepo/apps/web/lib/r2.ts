import {
  CopyObjectCommand,
  DeleteObjectCommand,
  HeadObjectCommand,
  S3Client,
  type HeadObjectCommandOutput,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { PutObjectCommand, GetObjectCommand } from "@aws-sdk/client-s3";

export interface R2ObjectMetadata {
  contentLength: number;
  contentType: string;
}

let client: S3Client | undefined;

export function isR2Configured(): boolean {
  return Boolean(
    process.env.R2_ACCOUNT_ID &&
      process.env.R2_BUCKET_NAME &&
      process.env.R2_ACCESS_KEY_ID &&
      process.env.R2_SECRET_ACCESS_KEY,
  );
}

function getR2Config() {
  const accountId = process.env.R2_ACCOUNT_ID;
  const bucket = process.env.R2_BUCKET_NAME;
  const accessKeyId = process.env.R2_ACCESS_KEY_ID;
  const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;

  if (!accountId || !bucket || !accessKeyId || !secretAccessKey) {
    throw new Error(
      "Cloudflare R2 belum dikonfigurasi. Lengkapi variabel R2_* di apps/web/.env.",
    );
  }

  return { accountId, bucket, accessKeyId, secretAccessKey };
}

function getClient() {
  if (!client) {
    const config = getR2Config();
    client = new S3Client({
      region: "auto",
      endpoint: `https://${config.accountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: config.accessKeyId,
        secretAccessKey: config.secretAccessKey,
      },
    });
  }
  return client;
}

export function storagePath(key: string): string {
  return `r2://${key}`;
}

export function parseStoragePath(path: string): string | null {
  if (!path.startsWith("r2://")) return null;
  const key = path.slice("r2://".length);
  if (
    !key ||
    key.startsWith("/") ||
    key.includes("\\") ||
    key.split("/").some((part) => !part || part === "." || part === "..")
  ) {
    return null;
  }
  return key;
}

export async function createUploadUrl(
  key: string,
  metadata: R2ObjectMetadata,
): Promise<string> {
  const { bucket } = getR2Config();
  const command = new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    ContentType: metadata.contentType,
    ContentLength: metadata.contentLength,
  });
  return getSignedUrl(getClient(), command, {
    expiresIn: 120,
    signableHeaders: new Set(["content-length", "content-type"]),
  });
}

export async function getDownloadUrl(key: string): Promise<string> {
  const { bucket } = getR2Config();
  return getSignedUrl(
    getClient(),
    new GetObjectCommand({ Bucket: bucket, Key: key }),
    { expiresIn: 300 },
  );
}

export async function promoteObject(
  sourceKey: string,
  destinationKey: string,
): Promise<void> {
  const { bucket } = getR2Config();
  await getClient().send(
    new CopyObjectCommand({
      Bucket: bucket,
      Key: destinationKey,
      CopySource: `${bucket}/${sourceKey
        .split("/")
        .map(encodeURIComponent)
        .join("/")}`,
      MetadataDirective: "COPY",
    }),
  );
  await deleteObject(sourceKey);
}

export async function deleteObject(key: string): Promise<void> {
  const { bucket } = getR2Config();
  await getClient().send(
    new DeleteObjectCommand({ Bucket: bucket, Key: key }),
  );
}

export async function headObject(
  key: string,
): Promise<HeadObjectCommandOutput | null> {
  const { bucket } = getR2Config();
  try {
    return await getClient().send(
      new HeadObjectCommand({ Bucket: bucket, Key: key }),
    );
  } catch (error) {
    if (
      typeof error === "object" &&
      error !== null &&
      "$metadata" in error &&
      (error as { $metadata?: { httpStatusCode?: number } }).$metadata
        ?.httpStatusCode === 404
    ) {
      return null;
    }
    throw error;
  }
}

export async function readObjectBytes(key: string): Promise<Uint8Array | null> {
  const { bucket } = getR2Config();
  const response = await getClient().send(
    new GetObjectCommand({ Bucket: bucket, Key: key }),
  );
  if (!response.Body) return null;
  return new Uint8Array(await response.Body.transformToByteArray());
}
