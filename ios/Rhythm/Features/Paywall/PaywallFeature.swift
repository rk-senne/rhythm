import ComposableArchitecture

@Reducer
struct PaywallFeature {
    @ObservableState
    struct State: Equatable {
        var isPro: Bool = false
        var packages: [PackageInfo] = []
        var isPurchasing: Bool = false
    }

    enum Action {
        case onAppear
        case proStatusChecked(Bool)
        case packagesLoaded([PackageInfo])
        case purchaseTapped(String)
        case purchaseResult(Bool)
        case restoreTapped
        case restoreResult(Bool)
    }

    @Dependency(\.paywallClient) var paywallClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let isPro = await paywallClient.checkProStatus()
                    await send(.proStatusChecked(isPro))
                    if !isPro {
                        let packages = try await paywallClient.getOfferings()
                        await send(.packagesLoaded(packages))
                    }
                }
            case let .proStatusChecked(isPro):
                state.isPro = isPro
                return .none
            case let .packagesLoaded(packages):
                state.packages = packages
                return .none
            case let .purchaseTapped(id):
                state.isPurchasing = true
                return .run { send in
                    let success = try await paywallClient.purchase(id)
                    await send(.purchaseResult(success))
                }
            case let .purchaseResult(success):
                state.isPurchasing = false
                state.isPro = success
                return .none
            case .restoreTapped:
                return .run { send in
                    let success = try await paywallClient.restore()
                    await send(.restoreResult(success))
                }
            case let .restoreResult(success):
                state.isPro = success
                return .none
            }
        }
    }
}
