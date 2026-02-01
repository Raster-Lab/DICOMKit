package com.dicomviewer;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Main entry point for the DICOM Viewer Backend application.
 * 
 * This Spring Boot application provides REST APIs for DICOM image management,
 * integrating with dcm4che library for DICOM protocol support.
 */
@SpringBootApplication
public class DicomViewerApplication {

    public static void main(String[] args) {
        SpringApplication.run(DicomViewerApplication.class, args);
    }
}
