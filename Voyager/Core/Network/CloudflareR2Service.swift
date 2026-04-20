import Foundation
import CryptoKit

// MARK: - Cloudflare R2 image upload service
//
// Uses R2's S3-compatible API with AWS Signature Version 4.
// Falls back to Supabase Storage when R2 is not yet configured.

final class CloudflareR2Service {
    static let shared = CloudflareR2Service()
    private init() {}

    private var endpoint: String {
        "https://\(CloudflareR2Config.accountId).r2.cloudflarestorage.com"
    }

    // ── Upload ────────────────────────────────────────────────────────────

    /// Upload image data to R2.  Returns the public URL of the uploaded object.
    func uploadImage(_ data: Data, path: String, contentType: String = "image/jpeg") async throws -> String {
        guard CloudflareR2Config.isConfigured else {
            throw CloudflareR2Error.notConfigured
        }

        let urlStr = "\(endpoint)/\(CloudflareR2Config.bucketName)/\(path)"
        guard let url = URL(string: urlStr) else { throw CloudflareR2Error.badURL }

        var request = URLRequest(url: url)
        request.httpMethod  = "PUT"
        request.httpBody    = data
        request.setValue(contentType,         forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)",     forHTTPHeaderField: "Content-Length")

        let signed = try signRequest(request, body: data)
        let (_, response) = try await URLSession.shared.data(for: signed)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw CloudflareR2Error.uploadFailed
        }

        return "\(CloudflareR2Config.publicBaseURL)/\(path)"
    }

    // ── AWS Signature Version 4 ───────────────────────────────────────────

    private func signRequest(_ request: URLRequest, body: Data) throws -> URLRequest {
        let now       = Date()
        let amzDate   = awsDateFormatter.string(from: now)          // e.g. 20240415T120000Z
        let dateStamp = String(amzDate.prefix(8))                   // e.g. 20240415
        let region    = "auto"
        let service   = "s3"
        let host      = request.url!.host!
        let bodyHash  = body.sha256HexString

        var req = request
        req.setValue(host,      forHTTPHeaderField: "Host")
        req.setValue(amzDate,   forHTTPHeaderField: "x-amz-date")
        req.setValue(bodyHash,  forHTTPHeaderField: "x-amz-content-sha256")

        // Headers must be sorted alphabetically for canonical form
        let signedHeaders = "content-type;host;x-amz-content-sha256;x-amz-date"
        let canonicalHeaders =
            "content-type:\(req.value(forHTTPHeaderField: "Content-Type") ?? "")\n" +
            "host:\(host)\n" +
            "x-amz-content-sha256:\(bodyHash)\n" +
            "x-amz-date:\(amzDate)\n"

        let canonicalRequest = [
            "PUT",
            req.url!.path,
            "",                    // query string
            canonicalHeaders,
            signedHeaders,
            bodyHash,
        ].joined(separator: "\n")

        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            canonicalRequest.sha256HexString,
        ].joined(separator: "\n")

        let signingKey = deriveSigningKey(dateStamp: dateStamp, region: region, service: service)
        let signature  = hmacSHA256(key: signingKey, data: Data(stringToSign.utf8)).hexString

        req.setValue(
            "AWS4-HMAC-SHA256 Credential=\(CloudflareR2Config.accessKeyId)/\(credentialScope), " +
            "SignedHeaders=\(signedHeaders), Signature=\(signature)",
            forHTTPHeaderField: "Authorization"
        )
        return req
    }

    private func deriveSigningKey(dateStamp: String, region: String, service: String) -> SymmetricKey {
        let initialKey = Data("AWS4\(CloudflareR2Config.secretKey)".utf8)
        let dateKey    = hmacSHA256(key: SymmetricKey(data: initialKey),     data: Data(dateStamp.utf8))
        let regionKey  = hmacSHA256(key: SymmetricKey(data: dateKey),        data: Data(region.utf8))
        let serviceKey = hmacSHA256(key: SymmetricKey(data: regionKey),      data: Data(service.utf8))
        let signingKey = hmacSHA256(key: SymmetricKey(data: serviceKey),     data: Data("aws4_request".utf8))
        return SymmetricKey(data: signingKey)
    }

    private func hmacSHA256(key: SymmetricKey, data: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: data, using: key))
    }

    // DateFormatter reused across calls
    private let awsDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        f.timeZone   = TimeZone(identifier: "UTC")
        return f
    }()
}

// MARK: - Errors

enum CloudflareR2Error: LocalizedError {
    case notConfigured
    case badURL
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Cloudflare R2 is not configured. Fill in CloudflareR2Config.swift."
        case .badURL:        return "Invalid R2 URL."
        case .uploadFailed:  return "Image upload to Cloudflare R2 failed."
        }
    }
}

// MARK: - Crypto helpers

private extension Data {
    var sha256HexString: String { SHA256.hash(data: self).hexString }
    var hexString: String       { map { String(format: "%02x", $0) }.joined() }
}

private extension String {
    var sha256HexString: String { Data(utf8).sha256HexString }
}

private extension SHA256.Digest {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
