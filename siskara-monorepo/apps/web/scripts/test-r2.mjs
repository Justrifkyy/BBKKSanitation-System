import { S3Client, ListObjectsV2Command, PutObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
import dotenv from "dotenv";
dotenv.config();

const accountId = process.env.R2_ACCOUNT_ID;
const bucket = process.env.R2_BUCKET_NAME;
const accessKeyId = process.env.R2_ACCESS_KEY_ID;
const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;

console.log("Testing R2 configuration...");
console.log("Account ID:", accountId);
console.log("Bucket:", bucket);
console.log("Access Key ID:", accessKeyId);

const client = new S3Client({
  region: "auto",
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId,
    secretAccessKey,
  },
});

async function main() {
  try {
    console.log("1. Listing objects in bucket...");
    const listRes = await client.send(new ListObjectsV2Command({ Bucket: bucket, MaxKeys: 5 }));
    console.log("Success! Objects count in bucket:", listRes.KeyCount);

    console.log("2. Testing put object...");
    const testKey = `test-health-${Date.now()}.txt`;
    await client.send(new PutObjectCommand({
      Bucket: bucket,
      Key: testKey,
      Body: "R2 connection healthy",
      ContentType: "text/plain",
    }));
    console.log("Success! Put object created:", testKey);

    console.log("3. Cleaning up test object...");
    await client.send(new DeleteObjectCommand({ Bucket: bucket, Key: testKey }));
    console.log("Success! Test object deleted.");

    console.log("\nCONCLUSION: Cloudflare R2 bucket and credentials are 100% WORKING!");
  } catch (err) {
    console.error("R2 ERROR:", err);
  }
}

main();
