# dicom-mpps - DICOM Modality Performed Procedure Step

Create and update DICOM Modality Performed Procedure Step (MPPS) instances.

## Features

- Create MPPS instances (N-CREATE) to notify procedure start
- Update MPPS instances (N-SET) to notify procedure completion
- Support for IN PROGRESS, COMPLETED, and DISCONTINUED states
- Reference image SOPs in completion notifications

## Usage

### Create MPPS (Procedure Started)

Create an MPPS instance when a procedure begins:
```bash
dicom-mpps create pacs://server:11112 \
  --aet MODALITY \
  --study-uid 1.2.3.4.5.6.7.8.9 \
  --status "IN PROGRESS"
```

The tool will output the MPPS Instance UID which you'll need for updates.

### Update MPPS (Procedure Completed)

Update an MPPS instance when a procedure completes:
```bash
dicom-mpps update pacs://server:11112 \
  --aet MODALITY \
  --mpps-uid 1.2.840.113619.2.xxx \
  --status COMPLETED
```

Update with referenced images:
```bash
dicom-mpps update pacs://server:11112 \
  --aet MODALITY \
  --mpps-uid 1.2.840.113619.2.xxx \
  --status COMPLETED \
  --study-uid 1.2.3.4.5 \
  --series-uid 1.2.3.4.5.6 \
  --image-uid 1.2.3.4.5.6.7 \
  --image-uid 1.2.3.4.5.6.8
```

### Discontinue Procedure

Mark a procedure as discontinued:
```bash
dicom-mpps update pacs://server:11112 \
  --aet MODALITY \
  --mpps-uid 1.2.840.113619.2.xxx \
  --status DISCONTINUED
```

## Options

### Create Command
- `--aet`: Local Application Entity Title (required)
- `--called-aet`: Remote Application Entity Title (default: ANY-SCP)
- `--study-uid`: Study Instance UID for the procedure (required)
- `--status`: Initial status (default: "IN PROGRESS")
- `--timeout`: Connection timeout in seconds (default: 60)
- `-v, --verbose`: Show verbose output

### Update Command
- `--aet`: Local Application Entity Title (required)
- `--called-aet`: Remote Application Entity Title (default: ANY-SCP)
- `--mpps-uid`: MPPS SOP Instance UID to update (required)
- `--status`: New status - COMPLETED or DISCONTINUED (required)
- `--study-uid`: Study Instance UID for referenced images
- `--series-uid`: Series Instance UID for referenced images
- `--image-uid`: SOP Instance UIDs for referenced images (can be repeated)
- `--timeout`: Connection timeout in seconds (default: 60)
- `-v, --verbose`: Show verbose output

## MPPS Workflow

1. **Procedure Start**: Create MPPS with status "IN PROGRESS"
2. **Procedure Execution**: Modality performs the imaging
3. **Procedure End**: Update MPPS with status "COMPLETED" and referenced images

## DICOM Reference

Implements PS3.4 Annex F - Modality Performed Procedure Step SOP Class

SOP Class UID: 1.2.840.10008.3.1.2.3.3
