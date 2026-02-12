import Foundation

// MARK: - Imaging Tools

extension ToolRegistry {

    static let dicomConvert = ToolDefinition(
        name: "DICOM Convert",
        command: "dicom-convert",
        category: .imaging,
        abstract: "Convert DICOM files to other formats",
        discussion: """
            Converts DICOM files to standard image formats (PNG, JPEG, TIFF) \
            or re-encodes with a different transfer syntax. Supports window/level \
            adjustments and batch processing.
            """,
        icon: "arrow.triangle.2.circlepath",
        parameters: [
            ToolParameter(
                name: "Input",
                cliFlag: "",
                type: .positionalFile(allowedTypes: ["dcm", "dicom", "dic"]),
                help: "Input DICOM file or directory",
                isRequired: true
            ),
            ToolParameter(
                name: "Output",
                cliFlag: "--output",
                type: .outputFile(allowedTypes: ["png", "jpg", "tiff", "dcm"]),
                help: "Output file path",
                isRequired: true
            ),
            ToolParameter(
                name: "Format",
                cliFlag: "--format",
                type: .dropdown(options: [
                    DropdownOption(label: "PNG", value: "png", help: "Lossless PNG format"),
                    DropdownOption(label: "JPEG", value: "jpeg", help: "Lossy JPEG format"),
                    DropdownOption(label: "TIFF", value: "tiff", help: "TIFF format"),
                    DropdownOption(label: "DICOM", value: "dicom", help: "Re-encode as DICOM"),
                ]),
                help: "Output image format"
            ),
            ToolParameter(
                name: "Transfer Syntax",
                cliFlag: "--transfer-syntax",
                type: .dropdown(options: [
                    DropdownOption(label: "Explicit VR Little Endian", value: "explicit-le",
                                   help: "Most common transfer syntax"),
                    DropdownOption(label: "Implicit VR Little Endian", value: "implicit-le",
                                   help: "Legacy transfer syntax"),
                    DropdownOption(label: "JPEG Baseline", value: "jpeg-baseline",
                                   help: "Lossy JPEG compression"),
                    DropdownOption(label: "JPEG Lossless", value: "jpeg-lossless",
                                   help: "Lossless JPEG compression"),
                    DropdownOption(label: "JPEG 2000", value: "jpeg2000",
                                   help: "JPEG 2000 compression"),
                    DropdownOption(label: "RLE", value: "rle",
                                   help: "Run-Length Encoding lossless compression"),
                ]),
                help: "Target DICOM transfer syntax (for DICOM output)",
                discussion: "Only applies when output format is DICOM"
            ),
            ToolParameter(
                name: "Quality",
                cliFlag: "--quality",
                type: .number,
                help: "JPEG quality (1–100)",
                defaultValue: "90"
            ),
            ToolParameter(
                name: "Apply Window/Level",
                cliFlag: "--apply-window",
                type: .flag,
                help: "Apply window/level adjustments to the output image",
                discussion: "Uses the window center and width stored in the file, or custom values if specified"
            ),
            ToolParameter(
                name: "Window Center",
                cliFlag: "--window-center",
                type: .number,
                help: "Custom window center value"
            ),
            ToolParameter(
                name: "Window Width",
                cliFlag: "--window-width",
                type: .number,
                help: "Custom window width value"
            ),
            ToolParameter(
                name: "Frame",
                cliFlag: "--frame",
                type: .number,
                help: "Export a specific frame from multi-frame files"
            ),
            ToolParameter(
                name: "Recursive",
                cliFlag: "--recursive",
                type: .flag,
                help: "Process files in subdirectories recursively"
            ),
            ToolParameter(
                name: "Strip Private",
                cliFlag: "--strip-private",
                type: .flag,
                help: "Remove private tags from DICOM output"
            ),
            ToolParameter(
                name: "Validate",
                cliFlag: "--validate",
                type: .flag,
                help: "Validate the output file after conversion"
            ),
            ToolParameter(
                name: "Force",
                cliFlag: "--force",
                type: .flag,
                help: "Force parsing of files without DICM prefix"
            ),
        ],
        examples: [
            "dicom-convert scan.dcm --output scan.png --format png",
            "dicom-convert scan.dcm -o scan.jpg --format jpeg --quality 85",
            "dicom-convert --apply-window --window-center 40 --window-width 400 ct.dcm -o ct.png",
        ]
    )

    static let dicomImage = ToolDefinition(
        name: "DICOM Image",
        command: "dicom-image",
        category: .imaging,
        abstract: "Convert standard images to DICOM Secondary Capture",
        discussion: """
            Creates DICOM Secondary Capture files from standard image formats \
            (PNG, JPEG, TIFF). Allows setting patient demographics and study metadata.
            """,
        icon: "photo.badge.plus",
        parameters: [
            ToolParameter(
                name: "Input Image",
                cliFlag: "",
                type: .positionalFile(allowedTypes: ["png", "jpg", "jpeg", "tiff", "bmp"]),
                help: "Input image file or directory",
                isRequired: true
            ),
            ToolParameter(
                name: "Output",
                cliFlag: "--output",
                type: .outputFile(allowedTypes: ["dcm"]),
                help: "Output DICOM file path"
            ),
            ToolParameter(
                name: "Patient Name",
                cliFlag: "--patient-name",
                type: .text,
                help: "Patient name (format: LASTNAME^FIRSTNAME)"
            ),
            ToolParameter(
                name: "Patient ID",
                cliFlag: "--patient-id",
                type: .text,
                help: "Patient identifier"
            ),
            ToolParameter(
                name: "Study Description",
                cliFlag: "--study-description",
                type: .text,
                help: "Description for the study"
            ),
            ToolParameter(
                name: "Series Description",
                cliFlag: "--series-description",
                type: .text,
                help: "Description for the series"
            ),
            ToolParameter(
                name: "Modality",
                cliFlag: "--modality",
                type: .dropdown(options: [
                    DropdownOption(label: "Other (OT)", value: "OT", help: "Other"),
                    DropdownOption(label: "Secondary Capture (SC)", value: "SC", help: "Secondary Capture"),
                    DropdownOption(label: "Digital Photography (XC)", value: "XC", help: "External-camera Photo"),
                    DropdownOption(label: "Endoscopy (ES)", value: "ES", help: "Endoscopy"),
                ]),
                help: "DICOM modality type",
                defaultValue: "OT"
            ),
            ToolParameter(
                name: "Study Instance UID",
                cliFlag: "--study-uid",
                type: .text,
                help: "Study Instance UID (auto-generated if not specified)"
            ),
            ToolParameter(
                name: "Series Instance UID",
                cliFlag: "--series-uid",
                type: .text,
                help: "Series Instance UID (auto-generated if not specified)"
            ),
            ToolParameter(
                name: "Use EXIF",
                cliFlag: "--use-exif",
                type: .flag,
                help: "Extract metadata from EXIF data in source image"
            ),
            ToolParameter(
                name: "Recursive",
                cliFlag: "--recursive",
                type: .flag,
                help: "Process files in subdirectories"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-image photo.jpg --output photo.dcm",
            "dicom-image photo.jpg --patient-name DOE^JOHN --patient-id P001",
            "dicom-image ./photos/ --recursive --output ./dicom/",
        ]
    )

    static let dicomCompress = ToolDefinition(
        name: "DICOM Compress",
        command: "dicom-compress",
        category: .imaging,
        abstract: "Compress or decompress DICOM pixel data",
        discussion: """
            Manage DICOM image compression using various codecs including JPEG, \
            JPEG Lossless, JPEG 2000, and RLE.
            """,
        icon: "archivebox",
        subcommands: [
            SubcommandDefinition(
                name: "compress",
                abstract: "Compress DICOM pixel data",
                parameters: [
                    ToolParameter(
                        name: "Input",
                        cliFlag: "",
                        type: .positionalFile(allowedTypes: ["dcm", "dicom"]),
                        help: "Input DICOM file",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Output",
                        cliFlag: "--output",
                        type: .outputFile(allowedTypes: ["dcm"]),
                        help: "Output file path",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Codec",
                        cliFlag: "--codec",
                        type: .dropdown(options: [
                            DropdownOption(label: "JPEG Baseline", value: "jpeg", help: "Lossy JPEG"),
                            DropdownOption(label: "JPEG Lossless", value: "jpeg-lossless", help: "Lossless JPEG"),
                            DropdownOption(label: "JPEG 2000", value: "jpeg2000", help: "JPEG 2000"),
                            DropdownOption(label: "JPEG 2000 Lossless", value: "jpeg2000-lossless",
                                           help: "Lossless JPEG 2000"),
                            DropdownOption(label: "RLE", value: "rle", help: "Run-Length Encoding"),
                        ]),
                        help: "Compression codec to use",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Quality",
                        cliFlag: "--quality",
                        type: .number,
                        help: "Compression quality (codec-dependent)"
                    ),
                    ToolParameter(
                        name: "Verbose",
                        cliFlag: "--verbose",
                        type: .flag,
                        help: "Show verbose output"
                    ),
                ]
            ),
            SubcommandDefinition(
                name: "decompress",
                abstract: "Decompress DICOM pixel data",
                parameters: [
                    ToolParameter(
                        name: "Input",
                        cliFlag: "",
                        type: .positionalFile(allowedTypes: ["dcm", "dicom"]),
                        help: "Input compressed DICOM file",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Output",
                        cliFlag: "--output",
                        type: .outputFile(allowedTypes: ["dcm"]),
                        help: "Output file path",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Transfer Syntax",
                        cliFlag: "--syntax",
                        type: .dropdown(options: [
                            DropdownOption(label: "Explicit VR Little Endian", value: "explicit-le",
                                           help: "Standard uncompressed"),
                            DropdownOption(label: "Implicit VR Little Endian", value: "implicit-le",
                                           help: "Legacy uncompressed"),
                        ]),
                        help: "Target transfer syntax"
                    ),
                    ToolParameter(
                        name: "Verbose",
                        cliFlag: "--verbose",
                        type: .flag,
                        help: "Show verbose output"
                    ),
                ]
            ),
            SubcommandDefinition(
                name: "info",
                abstract: "Show compression information",
                parameters: [
                    ToolParameter(
                        name: "Input",
                        cliFlag: "",
                        type: .positionalFile(allowedTypes: ["dcm", "dicom"]),
                        help: "Input DICOM file",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "JSON Output",
                        cliFlag: "--json",
                        type: .flag,
                        help: "Output as JSON"
                    ),
                ]
            ),
        ],
        examples: [
            "dicom-compress compress scan.dcm --output compressed.dcm --codec jpeg",
            "dicom-compress decompress compressed.dcm --output raw.dcm",
            "dicom-compress info scan.dcm",
        ]
    )

    static let dicomExport = ToolDefinition(
        name: "DICOM Export",
        command: "dicom-export",
        category: .imaging,
        abstract: "Advanced image export with contact sheets and animations",
        discussion: """
            Export DICOM images with advanced features including contact sheet \
            generation, animated GIF creation, and bulk export with organization.
            """,
        icon: "square.and.arrow.up",
        subcommands: [
            SubcommandDefinition(
                name: "single",
                abstract: "Export a single DICOM image",
                parameters: [
                    ToolParameter(
                        name: "Input",
                        cliFlag: "",
                        type: .positionalFile(allowedTypes: ["dcm", "dicom"]),
                        help: "Input DICOM file",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Output",
                        cliFlag: "--output",
                        type: .outputFile(allowedTypes: ["png", "jpg", "tiff"]),
                        help: "Output image path"
                    ),
                    ToolParameter(
                        name: "Format",
                        cliFlag: "--format",
                        type: .dropdown(options: [
                            DropdownOption(label: "PNG", value: "png", help: "Lossless PNG"),
                            DropdownOption(label: "JPEG", value: "jpeg", help: "Lossy JPEG"),
                            DropdownOption(label: "TIFF", value: "tiff", help: "TIFF format"),
                        ]),
                        help: "Output format",
                        defaultValue: "png"
                    ),
                    ToolParameter(
                        name: "Quality",
                        cliFlag: "--quality",
                        type: .number,
                        help: "JPEG quality (1–100)",
                        defaultValue: "90"
                    ),
                    ToolParameter(
                        name: "Embed Metadata",
                        cliFlag: "--embed-metadata",
                        type: .flag,
                        help: "Embed DICOM metadata as EXIF in exported image"
                    ),
                    ToolParameter(
                        name: "Apply Window/Level",
                        cliFlag: "--apply-window",
                        type: .flag,
                        help: "Apply window/level adjustments"
                    ),
                    ToolParameter(
                        name: "Frame",
                        cliFlag: "--frame",
                        type: .number,
                        help: "Export a specific frame number"
                    ),
                ]
            ),
            SubcommandDefinition(
                name: "animate",
                abstract: "Create an animated GIF from multi-frame DICOM",
                parameters: [
                    ToolParameter(
                        name: "Input",
                        cliFlag: "",
                        type: .positionalFile(allowedTypes: ["dcm", "dicom"]),
                        help: "Input multi-frame DICOM file",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Output",
                        cliFlag: "--output",
                        type: .outputFile(allowedTypes: ["gif"]),
                        help: "Output GIF file path",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "FPS",
                        cliFlag: "--fps",
                        type: .number,
                        help: "Frames per second",
                        defaultValue: "10"
                    ),
                    ToolParameter(
                        name: "Loop Count",
                        cliFlag: "--loop-count",
                        type: .number,
                        help: "Number of loops (0 = infinite)",
                        defaultValue: "0"
                    ),
                    ToolParameter(
                        name: "Scale",
                        cliFlag: "--scale",
                        type: .number,
                        help: "Scale factor for output (0.1–2.0)",
                        defaultValue: "1.0"
                    ),
                    ToolParameter(
                        name: "Apply Window/Level",
                        cliFlag: "--apply-window",
                        type: .flag,
                        help: "Apply window/level adjustments"
                    ),
                ]
            ),
            SubcommandDefinition(
                name: "bulk",
                abstract: "Bulk export DICOM files from a directory",
                parameters: [
                    ToolParameter(
                        name: "Input Directory",
                        cliFlag: "",
                        type: .positionalDirectory,
                        help: "Input directory containing DICOM files",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Output Directory",
                        cliFlag: "--output",
                        type: .outputDirectory,
                        help: "Output directory for exported images",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Format",
                        cliFlag: "--format",
                        type: .dropdown(options: [
                            DropdownOption(label: "PNG", value: "png", help: "Lossless PNG"),
                            DropdownOption(label: "JPEG", value: "jpeg", help: "Lossy JPEG"),
                            DropdownOption(label: "TIFF", value: "tiff", help: "TIFF format"),
                        ]),
                        help: "Output format",
                        defaultValue: "png"
                    ),
                    ToolParameter(
                        name: "Organize By",
                        cliFlag: "--organize-by",
                        type: .dropdown(options: [
                            DropdownOption(label: "Flat", value: "flat", help: "All files in one directory"),
                            DropdownOption(label: "Patient", value: "patient", help: "Organize by patient"),
                            DropdownOption(label: "Study", value: "study", help: "Organize by study"),
                            DropdownOption(label: "Series", value: "series", help: "Organize by series"),
                        ]),
                        help: "Directory organization scheme",
                        defaultValue: "flat"
                    ),
                    ToolParameter(
                        name: "Recursive",
                        cliFlag: "--recursive",
                        type: .flag,
                        help: "Process subdirectories"
                    ),
                    ToolParameter(
                        name: "Verbose",
                        cliFlag: "--verbose",
                        type: .flag,
                        help: "Show verbose output"
                    ),
                ]
            ),
        ],
        examples: [
            "dicom-export single scan.dcm --output scan.png",
            "dicom-export animate multiframe.dcm --output animation.gif --fps 15",
            "dicom-export bulk ./studies/ --output ./images/ --organize-by patient",
        ]
    )

    static let dicomSplit = ToolDefinition(
        name: "DICOM Split",
        command: "dicom-split",
        category: .imaging,
        abstract: "Split multi-frame DICOM files into individual frames",
        discussion: """
            Extracts individual frames from multi-frame DICOM files and saves \
            them as separate files.
            """,
        icon: "rectangle.split.3x1",
        parameters: [
            ToolParameter(
                name: "Input",
                cliFlag: "",
                type: .positionalFile(allowedTypes: ["dcm", "dicom"]),
                help: "Input multi-frame DICOM file",
                isRequired: true
            ),
            ToolParameter(
                name: "Output Directory",
                cliFlag: "--output",
                type: .outputDirectory,
                help: "Output directory for split frames"
            ),
            ToolParameter(
                name: "Frames",
                cliFlag: "--frames",
                type: .text,
                help: "Frame range to extract (e.g., 1-10, 5, 1-5,8-10)",
                discussion: "Specify individual frames or ranges separated by commas"
            ),
            ToolParameter(
                name: "Format",
                cliFlag: "--format",
                type: .dropdown(options: [
                    DropdownOption(label: "DICOM", value: "dicom", help: "Individual DICOM files"),
                    DropdownOption(label: "PNG", value: "png", help: "PNG images"),
                    DropdownOption(label: "JPEG", value: "jpeg", help: "JPEG images"),
                ]),
                help: "Output format for extracted frames",
                defaultValue: "dicom"
            ),
            ToolParameter(
                name: "Pattern",
                cliFlag: "--pattern",
                type: .text,
                help: "Output filename pattern (e.g., frame_%04d.dcm)"
            ),
            ToolParameter(
                name: "Apply Window/Level",
                cliFlag: "--apply-window",
                type: .flag,
                help: "Apply window/level adjustments (for image output)"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-split multiframe.dcm --output ./frames/",
            "dicom-split multiframe.dcm --frames 1-10 --format png",
        ]
    )

    static let dicomMerge = ToolDefinition(
        name: "DICOM Merge",
        command: "dicom-merge",
        category: .imaging,
        abstract: "Merge multiple DICOM files into a multi-frame series",
        discussion: """
            Combines multiple single-frame DICOM files into a multi-frame \
            DICOM file or organizes them into a consistent series.
            """,
        icon: "rectangle.stack.badge.plus",
        parameters: [
            ToolParameter(
                name: "Input Files",
                cliFlag: "",
                type: .positionalFiles(allowedTypes: ["dcm", "dicom"]),
                help: "Input DICOM files or directory",
                isRequired: true
            ),
            ToolParameter(
                name: "Output",
                cliFlag: "--output",
                type: .outputFile(allowedTypes: ["dcm"]),
                help: "Output merged DICOM file",
                isRequired: true
            ),
            ToolParameter(
                name: "Merge Level",
                cliFlag: "--level",
                type: .dropdown(options: [
                    DropdownOption(label: "Frame", value: "frame", help: "Merge as multi-frame"),
                    DropdownOption(label: "Series", value: "series", help: "Merge into series"),
                ]),
                help: "Merge strategy"
            ),
            ToolParameter(
                name: "Sort By",
                cliFlag: "--sort-by",
                type: .dropdown(options: [
                    DropdownOption(label: "Instance Number", value: "instance", help: "Sort by instance number"),
                    DropdownOption(label: "Acquisition Time", value: "time", help: "Sort by acquisition time"),
                    DropdownOption(label: "Filename", value: "filename", help: "Sort by filename"),
                    DropdownOption(label: "Slice Location", value: "location", help: "Sort by slice location"),
                ]),
                help: "Order of frames in merged file"
            ),
            ToolParameter(
                name: "Validate",
                cliFlag: "--validate",
                type: .flag,
                help: "Validate merged output"
            ),
            ToolParameter(
                name: "Recursive",
                cliFlag: "--recursive",
                type: .flag,
                help: "Search input directories recursively"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-merge frame1.dcm frame2.dcm frame3.dcm --output merged.dcm",
            "dicom-merge ./frames/ --output merged.dcm --sort-by location",
        ]
    )

    static let dicomPixedit = ToolDefinition(
        name: "DICOM Pixel Edit",
        command: "dicom-pixedit",
        category: .imaging,
        abstract: "Edit pixel data in DICOM files",
        discussion: """
            Perform pixel-level operations on DICOM images including masking \
            regions, cropping, inverting, and applying window/level.
            """,
        icon: "paintbrush.pointed",
        parameters: [
            ToolParameter(
                name: "Input",
                cliFlag: "",
                type: .positionalFile(allowedTypes: ["dcm", "dicom"]),
                help: "Input DICOM file",
                isRequired: true
            ),
            ToolParameter(
                name: "Output",
                cliFlag: "--output",
                type: .outputFile(allowedTypes: ["dcm"]),
                help: "Output DICOM file"
            ),
            ToolParameter(
                name: "Mask Region",
                cliFlag: "--mask-region",
                type: .text,
                help: "Region to mask (format: x,y,width,height)",
                discussion: "Pixel coordinates defining a rectangular region to mask"
            ),
            ToolParameter(
                name: "Fill Value",
                cliFlag: "--fill-value",
                type: .number,
                help: "Pixel value for masked regions",
                defaultValue: "0"
            ),
            ToolParameter(
                name: "Crop",
                cliFlag: "--crop",
                type: .text,
                help: "Crop region (format: x,y,width,height)"
            ),
            ToolParameter(
                name: "Apply Window/Level",
                cliFlag: "--apply-window",
                type: .flag,
                help: "Apply window/level to pixel data"
            ),
            ToolParameter(
                name: "Window Center",
                cliFlag: "--window-center",
                type: .number,
                help: "Window center value"
            ),
            ToolParameter(
                name: "Window Width",
                cliFlag: "--window-width",
                type: .number,
                help: "Window width value"
            ),
            ToolParameter(
                name: "Invert",
                cliFlag: "--invert",
                type: .flag,
                help: "Invert pixel values"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-pixedit scan.dcm --output masked.dcm --mask-region 0,0,100,100",
            "dicom-pixedit scan.dcm --invert --output inverted.dcm",
            "dicom-pixedit scan.dcm --crop 50,50,200,200 --output cropped.dcm",
        ]
    )

    static let dicomPdf = ToolDefinition(
        name: "DICOM PDF",
        command: "dicom-pdf",
        category: .imaging,
        abstract: "Encapsulate PDF in DICOM or extract PDF from DICOM",
        discussion: """
            Create DICOM Encapsulated PDF files from standard PDFs, or extract \
            embedded PDFs from DICOM files. Used for reports and documentation.
            """,
        icon: "doc.richtext",
        parameters: [
            ToolParameter(
                name: "Input",
                cliFlag: "",
                type: .positionalFile(allowedTypes: ["pdf", "dcm", "dicom"]),
                help: "Input PDF or DICOM file",
                isRequired: true
            ),
            ToolParameter(
                name: "Output",
                cliFlag: "--output",
                type: .outputFile(allowedTypes: ["dcm", "pdf"]),
                help: "Output file path"
            ),
            ToolParameter(
                name: "Extract",
                cliFlag: "--extract",
                type: .flag,
                help: "Extract PDF from DICOM (reverse operation)",
                discussion: "When set, extracts the embedded PDF from a DICOM encapsulated PDF file"
            ),
            ToolParameter(
                name: "Patient Name",
                cliFlag: "--patient-name",
                type: .text,
                help: "Patient name (format: LASTNAME^FIRSTNAME)"
            ),
            ToolParameter(
                name: "Patient ID",
                cliFlag: "--patient-id",
                type: .text,
                help: "Patient identifier"
            ),
            ToolParameter(
                name: "Title",
                cliFlag: "--title",
                type: .text,
                help: "Document title"
            ),
            ToolParameter(
                name: "Modality",
                cliFlag: "--modality",
                type: .dropdown(options: [
                    DropdownOption(label: "Document (DOC)", value: "DOC", help: "Document"),
                    DropdownOption(label: "Other (OT)", value: "OT", help: "Other"),
                ]),
                help: "DICOM modality",
                defaultValue: "DOC"
            ),
            ToolParameter(
                name: "Recursive",
                cliFlag: "--recursive",
                type: .flag,
                help: "Process files recursively"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-pdf report.pdf --output report.dcm --patient-name DOE^JOHN",
            "dicom-pdf report.dcm --extract --output extracted.pdf",
        ]
    )
}
