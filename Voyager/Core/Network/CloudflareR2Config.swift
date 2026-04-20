// MARK: - Cloudflare R2 Configuration
//
// Setup steps (one-time, free tier: 10 GB storage, no egress fees):
//  1. Sign up at dash.cloudflare.com
//  2. Go to R2 Object Storage → Create bucket (name it "voyager-images")
//  3. On the bucket → Settings → Public Access → Allow Access
//     Copy the "Public Bucket URL" (looks like https://pub-xxxx.r2.dev)
//  4. Go to R2 → Manage R2 API Tokens → Create API Token
//     Permissions: Object Read & Write  Scope: specific bucket "voyager-images"
//     Copy the "Access Key ID" and "Secret Access Key"
//  5. Your Account ID is in the top-right of the Cloudflare dashboard
//  6. Fill in the four values below and save.

enum CloudflareR2Config {
    /// Your Cloudflare account ID (32-char hex, visible in dashboard URL)
    static let accountId     = "fd0fc9b1c5a28511273354059123a6ba"

    /// Name of the R2 bucket you created
    static let bucketName    = "voyager-images"

    /// R2 API token — Access Key ID
    static let accessKeyId   = "59feef1e4a3948aed254981eed41c4b6"

    /// R2 API token — Secret Access Key
    static let secretKey     = "c26fb8e540f6d8c841fecd0d02f1a6a852ca1a21ee05ade4c23aee4a208541ef"

    /// Public bucket URL from bucket Settings → Public Access
    /// e.g. "https://pub-abc123def456.r2.dev"
    static let publicBaseURL = "https://pub-a6b6ba3de4bc400c9a0d38d2558288e2.r2.dev"

    // Derived
    static var isConfigured: Bool {
        !accountId.hasPrefix("YOUR_") && !accessKeyId.hasPrefix("YOUR_")
    }
}
