// MetadataView.swift
// DICOMViewer iOS - Metadata View
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI

/// View for displaying DICOM metadata
struct MetadataView: View {
    let study: DICOMStudy
    let series: DICOMSeries?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Patient Section
                Section("Patient") {
                    LabeledContent("Name", value: study.displayName)
                    LabeledContent("ID", value: study.patientID)
                    
                    if let sex = study.patientSex {
                        LabeledContent("Sex", value: sex)
                    }
                    
                    if let birthDate = study.patientBirthDate {
                        LabeledContent("Birth Date") {
                            Text(birthDate, style: .date)
                        }
                    }
                }
                
                // Study Section
                Section("Study") {
                    LabeledContent("UID") {
                        Text(study.studyInstanceUID)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    
                    if let date = study.studyDate {
                        LabeledContent("Date") {
                            Text(date, style: .date)
                        }
                    }
                    
                    if let description = study.studyDescription {
                        LabeledContent("Description", value: description)
                    }
                    
                    if let accession = study.accessionNumber {
                        LabeledContent("Accession #", value: accession)
                    }
                    
                    LabeledContent("Modalities", value: study.modalityString)
                    LabeledContent("Series Count", value: "\(study.seriesCount)")
                    LabeledContent("Image Count", value: "\(study.instanceCount)")
                }
                
                // Series Section
                if let series = series {
                    Section("Series") {
                        LabeledContent("UID") {
                            Text(series.seriesInstanceUID)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        
                        if let number = series.seriesNumber {
                            LabeledContent("Number", value: "\(number)")
                        }
                        
                        if let description = series.seriesDescription {
                            LabeledContent("Description", value: description)
                        }
                        
                        LabeledContent("Modality", value: series.modality)
                        
                        if let bodyPart = series.bodyPartExamined {
                            LabeledContent("Body Part", value: bodyPart)
                        }
                        
                        LabeledContent("Images", value: series.instanceCountString)
                        
                        if let dims = series.imageDimensions {
                            LabeledContent("Dimensions", value: dims)
                        }
                        
                        if let spacing = series.pixelSpacing, spacing.count >= 2 {
                            LabeledContent("Pixel Spacing") {
                                Text(String(format: "%.2f × %.2f mm", spacing[0], spacing[1]))
                            }
                        }
                        
                        if let thickness = series.sliceThickness {
                            LabeledContent("Slice Thickness") {
                                Text(String(format: "%.2f mm", thickness))
                            }
                        }
                    }
                }
                
                // Storage Section
                Section("Storage") {
                    LabeledContent("Size", value: study.storageSizeString)
                    LabeledContent("Imported") {
                        Text(study.createdAt, style: .date)
                    }
                    LabeledContent("Last Accessed") {
                        Text(study.lastAccessedAt, style: .relative)
                    }
                }
            }
            .navigationTitle("Study Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    let study = DICOMStudy(
        studyInstanceUID: "1.2.3.4.5.6.7.8.9",
        patientName: "DOE^JOHN",
        patientID: "12345",
        studyDate: Date(),
        studyDescription: "CT CHEST W/CONTRAST",
        seriesCount: 3,
        instanceCount: 150,
        modalities: ["CT"],
        storagePath: "/tmp"
    )
    return MetadataView(study: study, series: nil)
}
