import SwiftUI

struct MedicalDisclaimerView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasAcceptedMedicalDisclaimer") private var hasAccepted = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.orange)

                Text("disclaimer_title")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("disclaimer_message")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    hasAccepted = true
                    isPresented = false
                } label: {
                    Text("disclaimer_accept")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: 340)
            .padding(.vertical, 32)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
}

struct DisclaimerBanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("disclaimer_warning")
                    .font(.caption)
                    .foregroundColor(.orange)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MedicalDisclaimerView(isPresented: .constant(true))
}
