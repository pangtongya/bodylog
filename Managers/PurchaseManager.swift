// PurchaseManager.swift
// StoreKit 一次性买断购买管理

import Foundation
import StoreKit
import SwiftUI
import os.log

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    static let proProductID = "com.pangtong.formlog.pro"

    private static let logger = Logger(subsystem: "com.pangtong.formlog", category: "PurchaseManager")

    /// Timeout for StoreKit purchase requests
    private static let purchaseTimeout: Duration = .seconds(10)

    /// Maximum number of allowed restore-purchase retries
    private static let maxRestoreRetries = 3

    @Published var proProduct: Product?
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String?
    @Published var isLoadingProducts: Bool = false
    @Published var loadProductsError: String?

    /// Tracks how many times restorePurchases has been retried consecutively
    private var restoreRetryCount: Int = 0

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
                Self.logger.warning("Product not found for productID: \(Self.proProductID)")
                loadProductsError = L10n.string("无法找到商品，请检查配置。")
            } else {
                Self.logger.debug("Product loaded successfully: \(Self.proProductID)")
            }
        } catch {
            Self.logger.error("Load products error: \(error.localizedDescription)")
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
            Self.logger.warning("purchasePro called but proProduct is nil")
            purchaseError = L10n.string("无法加载商品，请检查网络后重试。")
            return
        }

        isPurchasing = true
        purchaseError = nil
        Self.logger.debug("Starting purchase for product: \(product.id)")

        do {
            let result = try await withThrowingTaskGroup(of: Product.PurchaseResult.self) { group in
                group.addTask {
                    try await product.purchase()
                }
                group.addTask {
                    try await Task.sleep(for: Self.purchaseTimeout)
                    throw PurchaseError.timeout
                }
                let result = try await group.next() ?? .userCancelled
                group.cancelAll()
                return result
            }

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Validate that the purchased product ID matches what was expected
                    guard transaction.productID == Self.proProductID else {
                        Self.logger.error("Product ID mismatch: expected=\(Self.proProductID), got=\(transaction.productID)")
                        await transaction.finish()
                        purchaseError = L10n.string("购买的商品ID不匹配，请联系支持。")
                        break
                    }
                    await transaction.finish()
                    Self.logger.info("Purchase verified and finished for product: \(transaction.productID)")
                    AppState.shared.isPro = true
                    AppState.shared.save()
                case .unverified(_, let error):
                    Self.logger.error("Purchase verification failed: \(error.localizedDescription)")
                    let errorMsg = String(format: L10n.string("购买验证失败：%@。可能原因：设备时间不正确、App Store 连接异常。请检查设备时间与网络后重试。"), error.localizedDescription)
                    purchaseError = errorMsg
                }
            case .userCancelled:
                Self.logger.debug("User cancelled purchase")
                break
            case .pending:
                Self.logger.info("Purchase is pending approval")
                purchaseError = L10n.string("购买待处理，请稍后查看。")
            @unknown default:
                Self.logger.error("Unknown purchase result case: \(String(describing: result))")
                purchaseError = L10n.string("购买处理失败，请联系支持。")
                break
            }
        } catch let error as PurchaseError where error == .timeout {
            Self.logger.error("Purchase timed out after \(Self.purchaseTimeout)")
            purchaseError = L10n.string("购买请求超时，请检查网络后重试。")
        } catch {
            Self.logger.error("Purchase failed: \(error.localizedDescription)")
            purchaseError = String(format: L10n.string("购买失败：%@"), error.localizedDescription)
        }

        isPurchasing = false
    }

    // MARK: - Restore

    func restorePurchases() async {
        guard restoreRetryCount < Self.maxRestoreRetries else {
            Self.logger.warning("Restore purchases skipped: retry limit reached (\(Self.maxRestoreRetries))")
            purchaseError = String(format: L10n.string("恢复购买重试次数已达上限（%d次），请稍后再试或联系支持。"), Self.maxRestoreRetries)
            return
        }

        isPurchasing = true
        restoreRetryCount += 1
        Self.logger.debug("Restoring purchases (attempt \(self.restoreRetryCount)/\(Self.maxRestoreRetries))")

        do {
            try await AppStore.sync()
            await checkPurchases()
            // Reset retry count on success
            restoreRetryCount = 0
            Self.logger.info("Restore purchases succeeded")
        } catch {
            Self.logger.error("Restore purchases failed (attempt \(self.restoreRetryCount)/\(Self.maxRestoreRetries)): \(error.localizedDescription)")
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
                    Self.logger.debug("Valid entitlement found for product: \(Self.proProductID)")
                    AppState.shared.isPro = true
                    AppState.shared.save()
                    return
                } else {
                    Self.logger.info("Transaction revoked for product: \(Self.proProductID), revocationDate: \(String(describing: transaction.revocationDate))")
                }
            } else {
                unverifiedCount += 1
                if case .unverified(_, let error) = result {
                    Self.logger.debug("Unverified transaction: \(error.localizedDescription)")
                } else if case .verified(let txn) = result {
                    Self.logger.debug("Verified transaction for non-pro product: \(txn.productID)")
                }
            }
        }
        // No valid entitlement found (including refunds/revocations)
        if !foundValid {
            AppState.shared.isPro = false
            AppState.shared.save()
            if unverifiedCount > 0 {
                Self.logger.info("Found \(unverifiedCount) unverified transaction(s)")
            }
        }
    }

    // MARK: - Listen

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    // Validate product ID before granting pro access
                    guard transaction.productID == Self.proProductID else {
                        Self.logger.warning("Transaction listener: ignoring non-pro product: \(transaction.productID)")
                        await transaction.finish()
                        continue
                    }

                    await transaction.finish()
                    Self.logger.info("Transaction listener: verified and finished transaction for \(transaction.productID)")
                    if transaction.revocationDate == nil {
                        await MainActor.run {
                            AppState.shared.isPro = true
                            AppState.shared.save()
                        }
                    } else {
                        Self.logger.info("Transaction listener: transaction is revoked for \(transaction.productID)")
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

// MARK: - Purchase Errors

private enum PurchaseError: Error, Equatable {
    case timeout
}
