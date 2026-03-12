import SwiftUI
import StoreKit

// MARK: - Store

@Observable
final class TipStore {

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case success
        case failed(String)
    }

    private(set) var product: Product? = nil
    var purchaseState: PurchaseState = .idle

    private let productID = "interweave.tip.coffee"

    func loadProduct() async {
        do {
            let fetched = try await Product.products(for: [productID])
            product = fetched.first
        } catch {
            product = nil
        }
    }

    func purchase() async {
        guard let product else { return }
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    purchaseState = .success
                case .unverified:
                    purchaseState = .failed("Purchase could not be verified.")
                }
            case .userCancelled, .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }
}

// MARK: - View

struct TipJarView: View {
    @State private var store = TipStore()
    @State private var showThankYou = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.pink.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.pink.gradient)
                    }

                    Text("Buy Me a Coffee")
                        .font(.title2).bold()

                    Text("Inner Wave is made with love and care. If it has brought calm to your day, consider buying me a coffee to help keep development going.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Button
                if let product = store.product {
                    Button {
                        Task { await store.purchase() }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.title3)
                                .foregroundStyle(.pink)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(product.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            if store.purchaseState == .purchasing {
                                ProgressView()
                                    .frame(width: 60)
                            } else {
                                Text(product.displayPrice)
                                    .font(.subheadline).bold()
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(.pink, in: Capsule())
                            }
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.purchaseState == .purchasing)
                } else {
                    ProgressView("Loading…")
                        .padding(.top, 40)
                }

                // Footer
                Text("Tips are one-time purchases and are non-refundable. Thank you for your generosity.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("Tip Jar")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showThankYou {
                thankYouOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showThankYou)
        .task { await store.loadProduct() }
        .onChange(of: store.purchaseState) { _, newValue in
            if newValue == .success {
                showThankYou = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.5))
                    showThankYou = false
                    store.purchaseState = .idle
                }
            }
        }
    }

    // MARK: Thank-you overlay

    private var thankYouOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.pink)

                Text("Thank You!")
                    .font(.title).bold()

                Text("Your support means the world.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        }
        .onTapGesture {
            showThankYou = false
            store.purchaseState = .idle
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TipJarView()
    }
}
