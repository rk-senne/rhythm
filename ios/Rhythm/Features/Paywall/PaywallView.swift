import SwiftUI
import ComposableArchitecture

struct PaywallView: View {
    let store: StoreOf<PaywallFeature>

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)
                Text("Rhythm Pro")
                    .font(.title.bold())
                Text("Unlock the full experience")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            // Features
            VStack(alignment: .leading, spacing: 12) {
                ProFeatureRow(icon: "timer", text: "Custom focus durations")
                ProFeatureRow(icon: "brain", text: "AI weekly summaries")
                ProFeatureRow(icon: "calendar", text: "Calendar write-back")
                ProFeatureRow(icon: "doc.text", text: "Export journals (PDF/JSON)")
            }
            .padding()

            Spacer()

            // Packages
            ForEach(store.packages) { pkg in
                Button {
                    store.send(.purchaseTapped(pkg.id))
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(pkg.period)
                                .font(.headline)
                            Text(pkg.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(pkg.price)
                            .font(.headline)
                    }
                    .padding()
                    .background(.indigo.opacity(0.1))
                    .cornerRadius(12)
                }
                .disabled(store.isPurchasing)
            }

            Button("Restore Purchases") { store.send(.restoreTapped) }
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear { store.send(.onAppear) }
    }
}

struct ProFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.indigo)
                .frame(width: 24)
            Text(text)
        }
    }
}
