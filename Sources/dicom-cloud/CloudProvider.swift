import Foundation
@preconcurrency import AWSS3
import AWSClientRuntime
import ClientRuntime
import Smithy

// MARK: - Cloud Provider Protocol
protocol CloudProviderProtocol: Actor {
    func upload(data: Data, to cloudURL: CloudURL, metadata: [String: String], encryption: EncryptionType) async throws
    func download(from cloudURL: CloudURL) async throws -> Data
    func list(cloudURL: CloudURL, recursive: Bool) async throws -> [CloudObject]
    func delete(cloudURL: CloudURL) async throws
    func exists(cloudURL: CloudURL) async throws -> Bool
}

// MARK: - Cloud Provider Factory
struct CloudProvider {
    static func create(for cloudURL: CloudURL, endpoint: String?, region: String?) async throws -> any CloudProviderProtocol {
        switch cloudURL.provider {
        case .s3:
            return try await S3Provider(endpoint: endpoint, region: region)
        case .gcs:
            throw CloudError.notImplemented("Google Cloud Storage support is planned but not yet implemented. Use S3-compatible mode for now.")
        case .azure:
            throw CloudError.notImplemented("Azure Blob Storage support is planned but not yet implemented. Use S3-compatible mode for now.")
        }
    }
}

// MARK: - S3 Provider
actor S3Provider: CloudProviderProtocol {
    private let client: S3Client
    
    init(endpoint: String?, region: String?) async throws {
        // Configure the S3 client
        do {
            let config = try await S3Client.S3ClientConfiguration(
                region: region
            )
            
            // If custom endpoint is provided, configure it
            if let endpoint = endpoint {
                config.endpoint = endpoint
            }
            
            self.client = S3Client(config: config)
        } catch {
            throw CloudError.authenticationFailed("Failed to create S3 client: \(error.localizedDescription)")
        }
    }
    
    func upload(data: Data, to cloudURL: CloudURL, metadata: [String: String], encryption: EncryptionType) async throws {
        do {
            // Convert Data to ByteStream
            let byteStream = ByteStream.data(data)
            
            // Build metadata for S3
            var s3Metadata: [String: String]?
            if !metadata.isEmpty {
                s3Metadata = metadata
            }
            
            // Configure encryption
            var serverSideEncryption: S3ClientTypes.ServerSideEncryption?
            if case .serverSide = encryption {
                serverSideEncryption = .aes256
            }
            
            // Create the PutObject request
            let input = PutObjectInput(
                body: byteStream,
                bucket: cloudURL.bucket,
                key: cloudURL.key,
                metadata: s3Metadata,
                serverSideEncryption: serverSideEncryption
            )
            
            _ = try await client.putObject(input: input)
        } catch let error as CloudError {
            throw error
        } catch {
            throw CloudError.operationFailed("Upload failed: \(error.localizedDescription)")
        }
    }
    
    func download(from cloudURL: CloudURL) async throws -> Data {
        do {
            let input = GetObjectInput(
                bucket: cloudURL.bucket,
                key: cloudURL.key
            )
            
            let output = try await client.getObject(input: input)
            
            guard let body = output.body else {
                throw CloudError.notFound("Object body is empty: \(cloudURL.key)")
            }
            
            // Convert ByteStream to Data
            guard let data = try await body.readData() else {
                throw CloudError.operationFailed("Failed to read object data: \(cloudURL.key)")
            }
            return data
        } catch let error as CloudError {
            throw error
        } catch {
            throw CloudError.operationFailed("Download failed: \(error.localizedDescription)")
        }
    }
    
    func list(cloudURL: CloudURL, recursive: Bool) async throws -> [CloudObject] {
        var objects: [CloudObject] = []
        var continuationToken: String?
        
        do {
            repeat {
                let input = ListObjectsV2Input(
                    bucket: cloudURL.bucket,
                    continuationToken: continuationToken,
                    delimiter: recursive ? nil : "/",
                    prefix: cloudURL.key.isEmpty ? nil : cloudURL.key
                )
                
                let output = try await client.listObjectsV2(input: input)
                
                if let contents = output.contents {
                    for s3Object in contents {
                        guard let key = s3Object.key else { continue }
                        
                        objects.append(CloudObject(
                            key: key,
                            size: Int(s3Object.size ?? 0),
                            lastModified: s3Object.lastModified ?? Date(),
                            metadata: [:]
                        ))
                    }
                }
                
                continuationToken = output.nextContinuationToken
            } while continuationToken != nil
            
            return objects
        } catch let error as CloudError {
            throw error
        } catch {
            throw CloudError.operationFailed("List failed: \(error.localizedDescription)")
        }
    }
    
    func delete(cloudURL: CloudURL) async throws {
        do {
            let input = DeleteObjectInput(
                bucket: cloudURL.bucket,
                key: cloudURL.key
            )
            
            _ = try await client.deleteObject(input: input)
        } catch let error as CloudError {
            throw error
        } catch {
            throw CloudError.operationFailed("Delete failed: \(error.localizedDescription)")
        }
    }
    
    func exists(cloudURL: CloudURL) async throws -> Bool {
        do {
            let input = HeadObjectInput(
                bucket: cloudURL.bucket,
                key: cloudURL.key
            )
            
            _ = try await client.headObject(input: input)
            return true
        } catch {
            // If HeadObject fails, the object doesn't exist
            return false
        }
    }
}
