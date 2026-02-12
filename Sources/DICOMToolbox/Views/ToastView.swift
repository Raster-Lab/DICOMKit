#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// A toast notification that briefly appears to report command completion status
public struct ToastView: View {
    let message: String
    let isSuccess: Bool

    public init(message: String, isSuccess: Bool) {
        self.message = message
        self.isSuccess = isSuccess
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isSuccess ? .green : .red)
            Text(message)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isSuccess ? "Success" : "Error"): \(message)")
    }
}

/// A view modifier that shows a toast notification
public struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let isSuccess: Bool
    let duration: TimeInterval

    public func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if isPresented {
                ToastView(message: message, isSuccess: isSuccess)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(duration))
                            withAnimation(.easeInOut) {
                                isPresented = false
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: isPresented)
    }
}

extension View {
    /// Shows a temporary toast notification
    public func toast(isPresented: Binding<Bool>, message: String, isSuccess: Bool, duration: TimeInterval = 3.0) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, isSuccess: isSuccess, duration: duration))
    }
}
#endif
