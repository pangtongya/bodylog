// PurchaseManager.swift
// StoreKit 一次性买断购买管理

import Foundation
import StoreKit
import SwiftUI

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    static let proProductID = "com.pangtong.formlog.pro"

    @Published var proProduct: Product?
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String?
    @Published var isLoadingProducts: Bool = false
    @Published var loadProductsError: String?

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactions()
    }

    /// Start loading products and verifying purchases - call this after init
    func start() async {
        await loadProducts()
        await checkPurchases()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoadingProducts = true
        loadProductsError = nil
        
        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
            if proProduct == nil {
                loadProductsError = L10n.string("无法找到商品，请检查配置。")
            }
        } catch {
            print("[PurchaseManager] Load products error: \(error)")
            loadProductsError = String(format: L10n.string("加载商品失败：%@"), error.localizedDescription)
        }
        
        isLoadingProducts = false
    }
    
    func retryLoadProducts() async {
        await loadProducts()
    }

    // MARK: - Purchase

    func purchasePro() async {
        guard let product = proProduct else {
            purchaseError = L10n.string("无法加载商品，请检查网络后重试。")
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
                case .unverified(_, let error):
                    // 提供更详细的错误信息和建议
                    let errorMsg = String(format: L10n.string("购买验证失败：%@。可能原因：设备时间不正确、App Store 连接异常。请检查设备时间与网络后重试。"), error.localizedDescription)
                    purchaseError = errorMsg
                }
            case .userCancelled:
                break
            case .pending:
                purchaseError = L10n.string("购买待处理，请稍后查看。")
            @unknown default:
                print("[PurchaseManager] Unknown purchase result case: \(result)")
                purchaseError = L10n.string("购买处理失败，请联系支持。")
                break
            }
        } catch {
            purchaseError = String(format: L10n.string("购买失败：%@"), error.localizedDescription)
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
            purchaseError = String(format: L10n.string("恢复购买失败：%@"), error.localizedDescription)
        }
        isPurchasing = false
    }

    // MARK: - Check

    func checkPurchases() async {
        var foundValid = false
        var unverifiedCount = 0
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID {
                if transaction.revocationDate == nil {
                    foundValid = true
                    AppState.shared.isPro = true
                    AppState.shared.save()
                    return
                }
            } else {
                // Log unverified transactions for debugging
                unverifiedCount += 1
                if case .unverified(_, let error) = result {
                    print("[PurchaseManager] Unverified transaction: \(error.localizedDescription)")
                } else {
                    print("[PurchaseManager] Unverified transaction found: \(result)")
                }
            }
        }
        // No valid entitlement found (including refunds/revocations)
        if !foundValid {
            AppState.shared.isPro = false
            AppState.shared.save()
            // 如果有未验证的交易，提供提示
            if unverifiedCount > 0 {
                print("[PurchaseManager] Found \(unverifiedCount) unverified transaction(s)")
            }
        }
    }

    // MARK: - Listen

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
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
        if let product = proProduct {
            return product.displayPrice
        } else if loadProductsError != nil {
            return L10n.string("加载失败，点击重试")
        } else if isLoadingProducts {
            return L10n.string("加载中...")
        } else {
            return L10n.string("加载中...")
        }
    }
    
    var canPurchase: Bool {
        proProduct != nil && !isPurchasing
    }
}
