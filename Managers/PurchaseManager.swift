// PurchaseManager.swift
// StoreKit 一次性买断购买管理

import Foundation
import StoreKit
import SwiftUI

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    static let proProductID = "com.pangtong.bodylog.pro"

    @Published var proProduct: Product?
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String?

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await checkPurchases()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
        } catch {
            print("[PurchaseManager] Load products error: \(error)")
        }
    }

    // MARK: - Purchase

    func purchasePro() async {
        guard let product = proProduct else {
            purchaseError = "无法加载商品，请检查网络后重试。"
            return
        }

        isPurchasing = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    AppState.shared.isPro = true
                    AppState.shared.save()
                case .unverified:
                    purchaseError = "购买验证失败，请联系支持。"
                }
            case .userCancelled:
                break
            case .pending:
                purchaseError = "购买待处理，请稍后查看。"
            @unknown default:
                break
            }
        } catch {
            purchaseError = "购买失败：\(error.localizedDescription)"
        }

        isPurchasing = false
    }

    // MARK: - Restore

    func restorePurchases() async {
        isPurchasing = true
        do {
            try await AppStore.sync()
            await checkPurchases()
        } catch {
            purchaseError = "恢复购买失败：\(error.localizedDescription)"
        }
        isPurchasing = false
    }

    // MARK: - Check

    func checkPurchases() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                AppState.shared.isPro = true
                AppState.shared.save()
                return
            }
        }
    }

    // MARK: - Listen

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    if transaction.productID == Self.proProductID,
                       transaction.revocationDate == nil {
                        await MainActor.run {
                            AppState.shared.isPro = true
                            AppState.shared.save()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Formatted Price

    var formattedPrice: String {
        proProduct?.displayPrice ?? "¥12"
    }
}
