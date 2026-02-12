#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-pixedit` tool, enabling pixel data
/// editing operations like masking, cropping, filling, and inverting.
public struct DicomPixeditView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomPixedit }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(
                title: "Input",
                help: "Select a DICOM file to edit pixel data.",
                isRequired: true
            ) {
                FileDropZoneView(
                    parameterID: "input",
                    label: "Input File",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Output
            ParameterSectionView(title: "Output", isRequired: true) {
                OutputPathView(
                    parameterID: "output",
                    label: "Output File",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Pixel Editing
            ParameterSectionView(
                title: "Pixel Editing",
                help: "Configure pixel editing operations. Mask and crop regions are specified as x,y,w,h coordinates."
            ) {
                HStack {
                    Text("Mask Region")
                    Spacer()
                    TextField("x,y,w,h", text: Binding(
                        get: { parameterValues["mask-region"] ?? "" },
                        set: { parameterValues["mask-region"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Region to mask, specified as x,y,width,height (e.g., 10,20,100,50)")

                HStack {
                    Text("Fill Value")
                    Spacer()
                    TextField("e.g. 0", text: Binding(
                        get: { parameterValues["fill-value"] ?? "" },
                        set: { parameterValues["fill-value"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 100)
                }
                .help("Pixel value to fill the masked region with (default: 0)")

                HStack {
                    Text("Crop")
                    Spacer()
                    TextField("x,y,w,h", text: Binding(
                        get: { parameterValues["crop"] ?? "" },
                        set: { parameterValues["crop"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Crop region, specified as x,y,width,height (e.g., 0,0,256,256)")

                Toggle("Invert", isOn: Binding(
                    get: { parameterValues["invert"] == "true" },
                    set: { parameterValues["invert"] = $0 ? "true" : "" }
                ))
                .help("Invert all pixel values in the image")
            }
        }
        .formStyle(.grouped)
    }
}
#endif
