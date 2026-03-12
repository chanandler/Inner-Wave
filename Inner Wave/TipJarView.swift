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

    private(set) var products: [Product] = []
    var purchaseState: PurchaseState = .idle

    private let productIDs: [String] = [
        "clintyarwood.innerwave.tip.small",
        "clintyarwood.innerwave.tip.med",
        "clintyarwood.innerwave.tip.large"
    ]

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: Set(productIDs))
            // Sort by price ascending so they always appear small → large
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Consumable tip — finish immediately, no entitlement to track
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
                headerSection
                    .padding(.top, 8)

                if store.products.isEmpty {
                    ProgressView("Loading…")
                        .padding(.top, 40)
                } else {
                    tipButtonsSection
                }

                footerNote
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
        .task { await store.loadProducts() }
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

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.pink.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "heart.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.pink.gradient)
            }

            Text("Support Inner Wave")
                .font(.title2).bold()

            Text("Inner Wave is made with love and care. If it has brought calm to your day, consider leaving a small tip to help keep development going.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Tip buttons

    private var tipButtonsSection: some View {
        VStack(spacing: 12) {
            ForEach(store.products) { product in
                tipButton(for: product)
            }
        }
    }

    private func tipButton(for product: Product) -> some View {
        Button {
            Task { await store.purchase(product) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: iconForProduct(product))
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

                Group {
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
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(store.purchaseState == .purchasing)
    }

    // MARK: Footer

    private var footerNote: some View {
        Text("Tips are one-time purchases and are non-refundable. Thank you for your generosity.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
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

    // MARK: Helpers

    private func iconForProduct(_ product: Product) -> String {
        switch product.id {
        case "clintyarwood.innerwave.tip.small":  return "heart"
        case "clintyarwood.innerwave.tip.med":    return "heart.fill"
        case "clintyarwood.innerwave.tip.large":  return "heart.circle.fill"
        default:                                   return "heart"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TipJarView()
    }
}
