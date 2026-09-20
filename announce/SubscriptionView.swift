import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("プレミアムプラン")) {
                    if subscriptionManager.isPremium {
                        Label("✅ プレミアム会員", systemImage: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    } else {
                        Text("月額 ¥120 で全機能が利用可能")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("プラン")) {
                    ForEach(subscriptionManager.products) { product in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(product.displayName)
                                .font(.headline)
                            Text(product.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(product.price, format: .currency(code: "JPY"))
                                .font(.title2.bold())
                                .foregroundColor(.blue)
                            
                            Button(action: {
                                Task {
                                    do {
                                        try await subscriptionManager.purchase()
                                    } catch {
                                        print("❌ 購入エラー：\(error)")
                                    }
                                }
                            }) {
                                Text("購入する")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(subscriptionManager.isPremium)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }) {
                        Label("購入を復元", systemImage: "arrow.counterclockwise")
                    }
                }
                
                Section(header: Text("注意事項")) {
                    Text("• 24 時間以内に自動的に更新されます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• 設定アプリからいつでもキャンセルできます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link("利用規約", destination: URL(string: "https://yourapp.com/terms")!)
                        .font(.caption)
                    Link("プライバシーポリシー", destination: URL(string: "https://yourapp.com/privacy")!)
                        .font(.caption)
                }
            }
            .navigationTitle("サブスクリプション")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await subscriptionManager.fetchProducts()
                    await subscriptionManager.refreshSubscriptionStatus()
                }
            }
        }
    }
}
