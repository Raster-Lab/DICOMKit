//
//  SeriesListView.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI

/// Series list view for a study
struct SeriesListView: View {
    let study: DicomStudy
    
    var body: some View {
        // Use multi-viewport viewer for the entire study
        MultiViewportView(study: study)
    }
}
