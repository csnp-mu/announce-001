import Foundation
import StoreKit
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var isPremium = false
    @Published var subscriptionState: SubscriptionState = .notSubscribed
    
    enum SubscriptionState {
        case notSubscribed
        case subscribed
        case expired
    }
    
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        startUpdateListener()
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // 購入可能なプロダクトを取得
    var products: [Product] = []
    
    func fetchProducts() async {
        do {
            // Product ID を設定（App Store Connect で設定した ID）
            let productIDs = ["com.yourapp.announce.premium_monthly"]
            products = try await Product.products(for: productIDs)
            print("🛒 取得したプロダクト：\(products.count) 件")
        } catch {
            print("❌ プロダクト取得エラー：\(error)")
        }
    }
    
    // サブスクリプション状態を確認
    func checkSubscriptionStatus() async {
        for await result in Transaction.updates {
            handleTransaction(result)
        }
    }
    
    // 現在の購入状況を確認
    func refreshSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            handleTransaction(result)
        }
    }
    
    private func handleTransaction(_ result: VerificationResult<Transaction>) {
        switch result {
        case .verified(let transaction):
            if transaction.revocationDate == nil {
                isPremium = true
                subscriptionState = .subscribed
                print("✅ サブスク有効：\(transaction.productID)")
            } else {
                isPremium = false
                subscriptionState = .expired
                print("❌ サブスク無効：\(transaction.productID)")
            }
        case .unverified:
            isPremium = false
            subscriptionState = .notSubscribed
            print("❌ 検証失敗")
        }
    }
    
    // サブスクリプション購入
    func purchase() async throws {
        guard let product = products.first else {
            throw SubscriptionError.noProducts
        }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await transaction.finish()
            isPremium = true
            subscriptionState = .subscribed
            print("✅ 購入成功：\(product.id)")
            
        case .userCancelled:
            print("🚫 ユーザーがキャンセル")
            
        case .pending:
            print("⏳ 保留中")
            
        @unknown default:
            print("❓ 不明な状態")
        }
    }
    
    // 購入履歴の復元
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            print("✅ 復元完了")
        } catch {
            print("❌ 復元エラー：\(error)")
        }
    }
    
    private func startUpdateListener() {
        updateListenerTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handleTransaction(result)
            }
        }
    }
}

enum SubscriptionError: LocalizedError {
    case noProducts
    case purchaseFailed
    
    var errorDescription: String? {
        switch self {
        case .noProducts:
            return "商品が見つかりません"
        case .purchaseFailed:
            return "購入に失敗しました"
        }
    }
}
