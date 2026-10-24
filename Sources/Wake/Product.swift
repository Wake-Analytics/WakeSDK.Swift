import Foundation

extension Wake {

    /// The param ids a purchase-product property fills, from the product and, when
    /// one is passed, its transaction. An event that carries one
    /// may not also design a property under any of these names — Wake refuses it,
    /// and so does the write behind the event form.
    ///
    /// They are flat and fixed rather than prefixed by the property's own id
    /// because an event may carry at most one purchase-product property, which
    /// is exactly what makes fixed names safe.
    public static let productParamIDs: Set<String> = [
        "product_id",
        "product_name",
        "price",
        "currency",
        "period",
        "product_type",
        "is_trial",
        "transaction_id",
    ]
}

/// A purchase's identity, for an event that was given a transaction. Carrying it
/// makes the event's id deterministic, so the same purchase logged twice — once
/// from the buy flow, once from a `Transaction.updates` replay at next launch —
/// collapses to one instance at ingest. It also carries the transaction's own
/// environment, which is what decides whether the purchase was a sandbox one, not
/// the flavour the build was compiled as.
struct TransactionIdentity {
    let id: String
    let isSandbox: Bool
}

/// What the SDK reads off a StoreKit product and its transaction. Held apart from
/// StoreKit so it can be built and tested without one.
struct ProductFacts {
    let productID: String
    let displayName: String
    let price: Double?
    let currencyCode: String?
    /// nil for anything that isn't a subscription.
    let period: String?
    let productType: String
    /// nil without a transaction: a product can say it HAS an introductory offer,
    /// never that one applied. Absence is a fact, and a wrong `false` is worse than
    /// a missing key.
    let isTrial: Bool?
    /// Present only when a transaction was passed, which is what marks the firing as a
    /// purchase rather than a product shown or chosen.
    let transactionID: String?

    /// The product's fields, over any params the caller passed. The product is the
    /// source of truth: a caller can add to the payload but never restate it.
    func params(custom: [String: Wake.ParamValue] = [:]) -> [String: Wake.ParamValue] {
        var params = ProductFacts.sanitize(custom)
        params["product_id"] = .string(productID)
        params["product_name"] = .string(displayName)
        params["product_type"] = .string(productType)
        if let price { params["price"] = .double(price) }
        if let currencyCode { params["currency"] = .string(currencyCode) }
        if let period { params["period"] = .string(period) }
        if let isTrial { params["is_trial"] = .bool(isTrial) }
        if let transactionID { params["transaction_id"] = .string(transactionID) }
        return params
    }

    /// Drops what a caller may not send: the product's own vocabulary, and empty
    /// ids. Each drop is a mistake worth hearing about, so each one logs.
    static func sanitize(_ custom: [String: Wake.ParamValue]) -> [String: Wake.ParamValue] {
        guard !custom.isEmpty else { return [:] }

        var kept: [String: Wake.ParamValue] = [:]
        kept.reserveCapacity(custom.count)
        for (id, value) in custom {
            guard !id.isEmpty else {
                Diag.error("a property with an empty id was dropped")
                continue
            }
            guard !Wake.productParamIDs.contains(id) else {
                Diag.error("`\(id)` comes from the purchase product and can't be overridden — dropped")
                continue
            }
            kept[id] = value
        }
        return kept
    }
}

#if canImport(StoreKit)
import StoreKit

extension Wake.Event {

    /// Not for direct use — backs a generated event that carries a purchase-product
    /// property.
    ///
    /// The whole product is read here rather than an identifier being passed,
    /// because what matters is what was true at the moment of the purchase: the
    /// price in the buyer's own storefront currency, and — with the transaction —
    /// whether an introductory offer applied. There is no product catalog to sync
    /// and nothing to look up later.
    ///
    /// A transaction makes the event's id derive from it, so the same purchase
    /// logged twice is one instance.
    public static func _event(
        _ name: String,
        params: [String: Wake.ParamValue] = [:],
        product: Product,
        transaction: Transaction?,
        screenTimeSince: [String: String] = [:],
        carries: [String] = [],
        carriedFrom: String? = nil,
        config: String? = nil
    ) -> Wake.Event {
        Wake.Event(
            name: name,
            params: ProductFacts(product, transaction: transaction).params(custom: params),
            screenTimeSince: screenTimeSince,
            carries: carries,
            carriedFrom: carriedFrom,
            transaction: transaction.map {
                TransactionIdentity(id: String($0.id), isSandbox: $0.environment != .production)
            },
            config: config
        )
    }
}

extension ProductFacts {

    init(_ product: Product, transaction: Transaction? = nil) {
        var isTrial: Bool?
        if let transaction, product.subscription != nil {
            isTrial = transaction.offerType == .introductory
        }

        self.init(
            productID: product.id,
            displayName: product.displayName,
            price: NSDecimalNumber(decimal: product.price).doubleValue,
            currencyCode: product.priceFormatStyle.currencyCode,
            period: product.subscription.map { ProductFacts.normalize($0.subscriptionPeriod) },
            productType: ProductFacts.normalize(product.type),
            isTrial: isTrial,
            transactionID: transaction.map { String($0.id) }
        )
    }

    static func normalize(_ p: Product.SubscriptionPeriod) -> String {
        switch (p.unit, p.value) {
        case (.year, _):      return "annual"
        case (.month, 1):     return "monthly"
        case (.month, let n): return "\(n)_month"
        case (.week, _):      return "weekly"
        case (.day, _):       return "daily"
        @unknown default:     return "unknown"
        }
    }

    static func normalize(_ type: Product.ProductType) -> String {
        switch type {
        case .consumable:    return "consumable"
        case .nonConsumable: return "non_consumable"
        case .autoRenewable: return "auto_renewable"
        case .nonRenewable:  return "non_renewable"
        default:             return "unknown"
        }
    }
}
#endif
