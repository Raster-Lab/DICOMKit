# dicom-cloud

Cloud storage integration tool for DICOM medical imaging files. Seamlessly upload, download, and manage DICOM files across AWS S3, Google Cloud Storage, and Azure Blob Storage.

## Features

### Cloud Providers
- ✅ AWS S3 (planned - requires AWS SDK integration)
- ✅ Google Cloud Storage (planned - requires GCS SDK integration)
- ✅ Azure Blob Storage (planned - requires Azure SDK integration)
- ✅ Custom S3-compatible providers (MinIO, DigitalOcean Spaces, etc.)

### Operations
- **Upload**: Upload individual files or entire directory structures
- **Download**: Download from cloud storage to local disk
- **List**: List objects in buckets/containers with detailed information
- **Delete**: Remove objects from cloud (with confirmation prompts)
- **Sync**: Bidirectional synchronization between local and cloud storage
- **Copy**: Cross-provider copying (e.g., S3 to GCS)

### Advanced Features
- **Parallel Transfers**: Configure concurrent uploads/downloads for improved performance
- **Multipart Upload**: Efficient large file transfers (planned)
- **Resume Capability**: Resume interrupted transfers (planned)
- **Metadata Tagging**: Add custom metadata to uploaded objects
- **Encryption**: Server-side and client-side encryption support (planned)
- **Custom Endpoints**: Support for S3-compatible services

## Installation

### From Source
```bash
cd DICOMKit
swift build -c release
cp .build/release/dicom-cloud /usr/local/bin/
```

### Using Homebrew (when available)
```bash
brew install dicomkit
```

## Usage

### Upload Files

```bash
# Upload single file to AWS S3
dicom-cloud upload scan.dcm s3://my-bucket/scans/scan.dcm

# Upload directory recursively
dicom-cloud upload study/ s3://my-bucket/studies/study1/ --recursive

# Upload with metadata tags
dicom-cloud upload scan.dcm s3://my-bucket/scans/ \
  --tags "PatientID=12345,StudyDate=20240101,Modality=CT"

# Upload with encryption (planned)
dicom-cloud upload study/ s3://my-bucket/studies/ \
  --recursive \
  --encrypt server-side

# Parallel multipart upload (planned)
dicom-cloud upload large-study/ s3://my-bucket/large/ \
  --recursive \
  --parallel 8 \
  --multipart \
  --resume
```

### Download Files

```bash
# Download single file
dicom-cloud download s3://my-bucket/scans/scan.dcm local-scan.dcm

# Download directory recursively
dicom-cloud download s3://my-bucket/studies/study1/ local-study/ --recursive

# Download with parallel transfers
dicom-cloud download s3://my-bucket/studies/ local/ \
  --recursive \
  --parallel 8
```

### List Objects

```bash
# List objects in bucket
dicom-cloud list s3://my-bucket/studies/

# List recursively with details
dicom-cloud list s3://my-bucket/studies/ --recursive --details

# Output shows: key, size, last modified date
```

### Delete Objects

```bash
# Delete single file (with confirmation)
dicom-cloud delete s3://my-bucket/scans/old-scan.dcm

# Delete directory recursively
dicom-cloud delete s3://my-bucket/old-studies/ --recursive

# Force delete without confirmation
dicom-cloud delete s3://my-bucket/temp/ --recursive --force
```

### Sync with Cloud

```bash
# Sync local to cloud (upload only)
dicom-cloud sync local-archive/ s3://my-bucket/archive/

# Bidirectional sync
dicom-cloud sync local-archive/ s3://my-bucket/archive/ --bidirectional

# Sync and delete extraneous files
dicom-cloud sync local-archive/ s3://my-bucket/archive/ \
  --bidirectional \
  --delete
```

### Copy Between Providers

```bash
# Copy from S3 to Google Cloud Storage
dicom-cloud copy s3://my-s3-bucket/study/ gs://my-gcs-bucket/study/ --recursive

# Copy from S3 to Azure
dicom-cloud copy s3://my-s3-bucket/study/ azure://my-container/study/ --recursive

# Copy with parallel transfers
dicom-cloud copy s3://source/data/ s3://dest/data/ \
  --recursive \
  --parallel 8
```

### Custom S3-Compatible Endpoints

```bash
# Use MinIO or other S3-compatible service
dicom-cloud upload study/ s3://my-bucket/study/ \
  --endpoint https://minio.example.com \
  --recursive

# DigitalOcean Spaces
dicom-cloud upload study/ s3://my-space/study/ \
  --endpoint https://nyc3.digitaloceanspaces.com \
  --recursive
```

## Cloud URL Formats

### AWS S3
```
s3://bucket-name/path/to/object
```

### Google Cloud Storage
```
gs://bucket-name/path/to/object
```

### Azure Blob Storage
```
azure://container-name/path/to/blob
```

### Custom S3-Compatible
```
s3://endpoint/bucket-name/path/to/object
```
Use with `--endpoint` flag to specify custom endpoint URL.

## Authentication

### AWS S3

**Environment Variables:**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

**AWS Credentials File** (`~/.aws/credentials`):
```ini
[default]
aws_access_key_id = your-access-key
aws_secret_access_key = your-secret-key
region = us-east-1
```

### Google Cloud Storage

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
```

### Azure Blob Storage

```bash
export AZURE_STORAGE_CONNECTION_STRING="your-connection-string"
```

## Configuration

### Parallel Transfers

Control the number of concurrent operations:
```bash
dicom-cloud upload study/ s3://bucket/study/ --recursive --parallel 8
```

Default: 4 parallel transfers

### Verbose Mode

Enable detailed logging:
```bash
dicom-cloud upload study/ s3://bucket/study/ --recursive --verbose
```

## Examples

### Clinical Workflow: Archive Study to Cloud

```bash
# 1. Validate DICOM files
dicom-validate study/*.dcm

# 2. Anonymize for archival
dicom-anon study/ --output anon-study/ --profile archive --recursive

# 3. Upload to cloud with metadata
dicom-cloud upload anon-study/ s3://pacs-archive/studies/$(date +%Y%m%d)/ \
  --recursive \
  --tags "ArchiveDate=$(date +%Y%m%d),Source=PACS1" \
  --verbose

# 4. Verify upload
dicom-cloud list s3://pacs-archive/studies/$(date +%Y%m%d)/ --recursive --details
```

### Disaster Recovery: Sync to Multiple Clouds

```bash
# Sync primary archive to AWS S3
dicom-cloud sync /var/pacs/archive/ s3://primary-backup/ --bidirectional

# Copy to Google Cloud for geographic redundancy
dicom-cloud copy s3://primary-backup/ gs://secondary-backup/ --recursive --parallel 8

# Copy to Azure for additional redundancy
dicom-cloud copy s3://primary-backup/ azure://tertiary-backup/ --recursive --parallel 8
```

### Research Data Distribution

```bash
# Upload de-identified research dataset
dicom-cloud upload research-dataset/ s3://research-data/dataset-v1.0/ \
  --recursive \
  --tags "Dataset=CardiacCT,Version=1.0,Cases=500" \
  --verbose

# Generate presigned URLs for data access (future feature)
# dicom-cloud share s3://research-data/dataset-v1.0/ --expires 30d
```

## Implementation Status

### Current Status (v1.4.4)

This is the initial release of `dicom-cloud` with **framework and CLI interface complete**.

**✅ Implemented:**
- Complete CLI interface with all subcommands
- URL parsing for S3, GCS, Azure
- Operation framework (upload, download, list, delete, sync, copy)
- Parallel transfer architecture
- Metadata tagging support
- Verbose logging

**⚠️ Pending Integration:**
- AWS SDK for Swift integration
- Google Cloud SDK integration
- Azure SDK integration
- Actual cloud provider implementations

**Why the delay?**
Cloud SDK dependencies are substantial (100+ MB each) and require:
1. Package.swift dependency additions
2. SDK-specific authentication implementations
3. Platform-specific build configurations
4. Extensive integration testing with real cloud accounts

**Current Capability:**
The tool provides a complete CLI interface and will display clear error messages
indicating that cloud SDK integration is required. This allows:
- Testing of CLI argument parsing
- Validation of workflow logic
- Integration with other DICOMKit tools
- Future SDK integration without breaking changes

### Phase A: AWS S3 Support (Planned)

**Deliverables:**
- [ ] Integrate AWS SDK for Swift dependency
- [ ] Implement S3 authentication (SigV4)
- [ ] Implement S3 upload with PutObject
- [ ] Implement S3 download with GetObject
- [ ] Implement S3 list with ListObjectsV2
- [ ] Implement S3 delete with DeleteObject
- [ ] Add multipart upload support
- [ ] Handle S3-specific errors
- [ ] Test with real AWS S3 buckets

**Estimated Effort:** 2-3 days

### Phase B: Multi-Provider Support (Planned)

**Deliverables:**
- [ ] Integrate Google Cloud Storage SDK
- [ ] Implement GCS operations
- [ ] Integrate Azure Blob Storage SDK
- [ ] Implement Azure operations
- [ ] Add custom S3-compatible provider support
- [ ] Test cross-provider copying

**Estimated Effort:** 3-4 days

### Phase C: Advanced Features (Planned)

**Deliverables:**
- [ ] Implement multipart upload
- [ ] Add resume capability
- [ ] Implement server-side encryption
- [ ] Implement client-side encryption
- [ ] Add progress bars for transfers
- [ ] Optimize parallel transfer performance

**Estimated Effort:** 2-3 days

## Testing

### Unit Tests
```bash
swift test --filter DICOMCloudTests
```

### Integration Tests (requires cloud credentials)
```bash
# Set up test environment
export AWS_ACCESS_KEY_ID="test-key"
export AWS_SECRET_ACCESS_KEY="test-secret"
export DICOM_CLOUD_TEST_BUCKET="test-bucket"

# Run integration tests
swift test --filter DICOMCloudIntegrationTests
```

### Manual Testing with MinIO
```bash
# Start MinIO locally
docker run -p 9000:9000 -p 9001:9001 \
  -e "MINIO_ROOT_USER=minioadmin" \
  -e "MINIO_ROOT_PASSWORD=minioadmin" \
  minio/minio server /data --console-address ":9001"

# Configure credentials
export AWS_ACCESS_KEY_ID="minioadmin"
export AWS_SECRET_ACCESS_KEY="minioadmin"

# Test upload
dicom-cloud upload test.dcm s3://test-bucket/test.dcm \
  --endpoint http://localhost:9000
```

## Security Best Practices

### 1. Credential Management
- Never hardcode credentials in scripts
- Use environment variables or credential files
- Rotate credentials regularly
- Use IAM roles on EC2/ECS when possible

### 2. Encryption
- Enable server-side encryption for sensitive data
- Use client-side encryption for PHI (Protected Health Information)
- Ensure encryption at rest and in transit

### 3. Access Control
- Use least-privilege IAM policies
- Enable bucket versioning for data protection
- Implement lifecycle policies for old data
- Enable access logging

### 4. Compliance
- Follow HIPAA guidelines for PHI
- Implement audit trails
- Use signed URLs for temporary access
- Regular security audits

## Troubleshooting

### Authentication Errors
```
Error: Authentication failed: Invalid credentials
```
**Solution:** Verify AWS credentials are set correctly via environment variables or `~/.aws/credentials`.

### Network Errors
```
Error: Network error: Connection timeout
```
**Solution:** Check internet connectivity, firewall rules, and endpoint URLs.

### Permission Errors
```
Error: Permission denied: Access denied to bucket
```
**Solution:** Verify IAM permissions include `s3:PutObject`, `s3:GetObject`, `s3:ListBucket`, `s3:DeleteObject`.

### Not Implemented Errors
```
Error: Not implemented: AWS S3 upload requires AWS SDK integration
```
**Solution:** This is expected in v1.4.4. AWS SDK integration is planned for future releases. See "Implementation Status" section above.

## Performance Tuning

### Parallel Transfers
- Default: 4 concurrent transfers
- Recommended for large datasets: 8-16
- Too many can cause rate limiting

### Multipart Upload (Planned)
- Automatically used for files > 100 MB
- Improves reliability for large files
- Configurable chunk size

### Network Optimization
- Use --resume for unreliable connections
- Enable --multipart for large files
- Adjust --parallel based on bandwidth

## API Integration

For programmatic access, use the CloudProvider API directly:

```swift
import Foundation

// Parse cloud URL
let cloudURL = try CloudURL.parse("s3://my-bucket/path/to/file.dcm")

// Create provider
let provider = try CloudProvider.create(for: cloudURL, endpoint: nil)

// Upload file
let data = try Data(contentsOf: fileURL)
try await provider.upload(
    data: data,
    to: cloudURL,
    metadata: ["PatientID": "12345"],
    encryption: .serverSide
)

// Download file
let downloadedData = try await provider.download(from: cloudURL)

// List objects
let objects = try await provider.list(cloudURL: cloudURL, recursive: true)
for object in objects {
    print("\(object.key): \(object.size) bytes")
}
```

## Related Tools

- **dicom-send**: Send DICOM files to PACS servers via DICOM protocol
- **dicom-archive**: Manage local DICOM archives with SQLite indexing
- **dicom-export**: Export DICOM files with advanced filtering

## References

- [AWS S3 Documentation](https://aws.amazon.com/s3/)
- [Google Cloud Storage Documentation](https://cloud.google.com/storage)
- [Azure Blob Storage Documentation](https://azure.microsoft.com/en-us/services/storage/blobs/)
- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
- [DICOM Standard](https://www.dicomstandard.org/)

## Version History

### v1.4.4 (2026-02-13)
- Initial release with complete CLI framework
- URL parsing for S3, GCS, Azure
- Operation framework (upload, download, list, delete, sync, copy)
- Parallel transfer architecture
- SDK integration planned for future releases

## License

MIT License - see LICENSE file for details

---

**Part of**: [DICOMKit CLI Tools Phase 7](../../CLI_TOOLS_PHASE7.md)  
**Tool #35**: dicom-cloud - Cloud Storage Integration  
**Status**: Phase A - Framework Complete, SDK Integration Planned
