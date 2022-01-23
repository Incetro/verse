//
//  Store.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Combine
import Foundation

// MARK: - Store

/// A store represents the runtime that powers the application. It is the object that you will pass
/// around to views that need to interact with the application.
///
/// You will typically construct a single one of these at the root of your application, and then use
/// the `scope` method to derive more focused stores that can be passed to subviews
public final class Store<State, Action> {

    // MARK: - Properties

    var state: CurrentValueSubject<State, Never>
    var effectCancellables: [UUID: AnyCancellable] = [:]
    private var isSending = false
    private var parentCancellable: AnyCancellable?
    private var contextCancellable: AnyCancellable?
    private let reducer: (inout State, Action) -> Effect<Action, Never>
    private var synchronousActionsToSend: [Action] = []
    private var bufferedActions: [Action] = []

    // MARK: - Initializers

    /// Initializes a store from an initial state, a reducer, and an environment.
    ///
    /// - Parameters:
    ///   - initialState: the state to start the application in
    ///   - reducer: the reducer that powers the business logic of the application
    ///   - environment: the environment of dependencies for the application
    public convenience init<Environment>(
        initialState: State,
        reducer: Reducer<State, Action, Environment>,
        environment: Environment
    ) {
        self.init(
            initialState: initialState,
            reducer: { reducer.run(&$0, $1, environment) }
        )
    }

    private init(
        initialState: State,
        reducer: @escaping (inout State, Action) -> Effect<Action, Never>
    ) {
        self.reducer = reducer
        self.state = CurrentValueSubject(initialState)
    }

    // MARK: - Scope

    /// Scopes the store to one that exposes local state and actions
    ///
    /// This can be useful for deriving new stores to hand to child views in an application. For
    /// example:
    ///
    ///     // Application state made from local states.
    ///     struct AppState {
    ///         var login: LoginState
    ///         ...
    ///     }
    ///
    ///     struct AppAction {
    ///         case login(LoginAction)
    ///         ...
    ///     }
    ///
    ///     // A store that runs the entire application.
    ///     let store = Store(
    ///         initialState: AppState(),
    ///         reducer: appReducer,
    ///         environment: AppEnvironment()
    ///     )
    ///
    ///     // Construct a login view by scoping the store to one that works with only login domain.
    ///     LoginView(
    ///         store: store.scope(
    ///             state: { $0.login },
    ///             action: { AppAction.login($0) }
    ///         )
    ///     )
    ///
    /// Scoping in this fashion allows you to better modularize your application. In this case,
    /// `LoginView` could be extracted to a module that has no access to `AppState` or `AppAction`
    ///
    /// Scoping also gives a view the opportunity to focus on just the state and actions it cares
    /// about, even if its feature domain is larger
    ///
    /// For example, the above login domain could model a two screen login flow: a login form followed
    /// by a two-factor authentication screen. The second screen's domain might be nested in the
    /// first:
    ///
    ///     struct LoginState: Equatable {
    ///         var email = ""
    ///         var password = ""
    ///         var twoFactorAuth: TwoFactorAuthState?
    ///     }
    ///
    ///     enum LoginAction: Equatable {
    ///         case emailChanged(String)
    ///         case loginButtonTapped
    ///         case loginResponse(Result<TwoFactorAuthState, LoginError>)
    ///         case passwordChanged(String)
    ///         case twoFactorAuth(TwoFactorAuthAction)
    ///     }
    ///
    /// The login view holds onto a store of this domain:
    ///
    ///     struct LoginView: View {
    ///       let store: Store<LoginState, LoginAction>
    ///
    ///       var body: some View { ... }
    ///     }
    ///
    /// If its body were to use a view store of the same domain, this would introduce a number of
    /// problems:
    ///
    /// * The login view would be able to read from `twoFactorAuth` state. This state is only intended
    ///   to be read from the two-factor auth screen
    ///
    /// * Even worse, changes to `twoFactorAuth` state would now cause SwiftUI to recompute
    ///   `LoginView`'s body unnecessarily
    ///
    /// * The login view would be able to send `twoFactorAuth` actions. These actions are only
    ///   intended to be sent from the two-factor auth screen (and reducer)
    ///
    /// * The login view would be able to send non user-facing login actions, like `loginResponse`.
    ///   These actions are only intended to be used in the login reducer to feed the results of
    ///   effects back into the store
    ///
    /// To avoid these issues, one can introduce a view-specific domain that slices off the subset of
    /// state and actions that a view cares about:
    ///
    ///     extension LoginView {
    ///
    ///         struct State: Equatable {
    ///             var email: String
    ///             var password: String
    ///         }
    ///
    ///         enum Action: Equatable {
    ///             case emailChanged(String)
    ///             case loginButtonTapped
    ///             case passwordChanged(String)
    ///         }
    ///     }
    ///
    /// One can also introduce a couple helpers that transform feature state into view state and
    /// transform view actions into feature actions
    ///
    ///     extension LoginState {
    ///         var view: LoginView.State {
    ///             .init(email: self.email, password: self.password)
    ///         }
    ///     }
    ///
    ///     extension LoginView.Action {
    ///         var feature: LoginAction {
    ///             switch self {
    ///             case let .emailChanged(email)
    ///                 return .emailChanged(email)
    ///             case .loginButtonTapped:
    ///                 return .loginButtonTapped
    ///             case let .passwordChanged(password)
    ///                 return .passwordChanged(password)
    ///             }
    ///         }
    ///     }
    ///
    /// With these helpers defined, `LoginView` can now scope its store's feature domain into its view
    /// domain:
    ///
    ///     var body: some View {
    ///         WithViewStore(
    ///             self.store.scope(
    ///                 state: { $0.view },
    ///                 action: { $0.feature }
    ///             )
    ///         ) { viewStore in
    ///             ...
    ///         }
    ///     }
    ///
    /// This view store is now incapable of reading any state but view state (and will not recompute
    /// when non-view state changes), and is incapable of sending any actions but view actions
    ///
    /// - Parameters:
    ///   - toLocalState: a function that transforms `State` into `LocalState`
    ///   - fromLocalAction: a function that transforms `LocalAction` into `Action`
    /// - Returns: a new store with its domain (state and action) transformed
    public func scope<LocalState, LocalAction>(
        state toLocalState: @escaping (State) -> LocalState,
        action fromLocalAction: @escaping (LocalAction) -> Action
    ) -> Store<LocalState, LocalAction> {
        let localStore = Store<LocalState, LocalAction>(
            initialState: toLocalState(self.state.value),
            reducer: { localState, localAction in
                self.send(fromLocalAction(localAction))
                localState = toLocalState(self.state.value)
                return .none
            }
        )
        localStore.parentCancellable = state
            .sink { [weak localStore] newValue in localStore?.state.value = toLocalState(newValue) }
        return localStore
    }

    /// Scopes the store to one that exposes local state
    ///
    /// - Parameter toLocalState: a function that transforms `State` into `LocalState`
    /// - Returns: a new store with its domain (state and action) transformed
    public func scope<LocalState>(
        state toLocalState: @escaping (State) -> LocalState
    ) -> Store<LocalState, Action> {
        scope(state: toLocalState, action: { $0 })
    }

    /// Scopes the store to a publisher of stores of more local state and local actions
    ///
    /// - Parameters:
    ///   - toLocalState: a function that transforms a publisher of `State` into a publisher of `LocalState`
    ///   - fromLocalAction: a function that transforms `LocalAction` into `Action`
    /// - Returns: a publisher of stores with its domain (state and action) transformed
    public func publisherScope<P: Publisher, LocalState, LocalAction>(
        state toLocalState: @escaping (AnyPublisher<State, Never>) -> P,
        action fromLocalAction: @escaping (LocalAction) -> Action
    ) -> AnyPublisher<Store<LocalState, LocalAction>, Never>
    where P.Output == LocalState, P.Failure == Never {

        func extractLocalState(_ state: State) -> LocalState? {
            var localState: LocalState?
            _ = toLocalState(Just(state).eraseToAnyPublisher())
                .sink { localState = $0 }
            return localState
        }

        return toLocalState(self.state.eraseToAnyPublisher())
            .map { localState in
                let localStore = Store<LocalState, LocalAction>(
                    initialState: localState,
                    reducer: { localState, localAction in
                        self.send(fromLocalAction(localAction))
                        localState = extractLocalState(self.state.value) ?? localState
                        return .none
                    }
                )
                localStore.parentCancellable = self.state
                    .sink { [weak localStore] state in
                        guard let localStore = localStore else { return }
                        localStore.state.value = extractLocalState(state) ?? localStore.state.value
                    }
                return localStore
            }
            .eraseToAnyPublisher()
    }

    public func scopeWithShared<SharedState, GlobalPrivateState, LocalPrivateState, LocalAction>(
        state toLocalPrivateState: @escaping (GlobalPrivateState) -> LocalPrivateState,
        action toGlobalAction: @escaping (LocalAction) -> Action
    ) -> Store<CombinedState<SharedState, LocalPrivateState>, LocalAction>
    where State == CombinedState<SharedState, GlobalPrivateState> {
        scope(state: { globalState in
            CombinedState(
                shared: globalState.shared,
                private: toLocalPrivateState(globalState.private)
            )
        }, action: toGlobalAction)
    }

    public func withContext<Context>(contextHandle: ContextHandle<Context>) -> Store<Merged<Context, State>, Action> {
        let localStore = self.scope(
            state: { Merged<Context, State>(context: contextHandle.context, state: $0) }
        )
        localStore.contextCancellable = contextHandle.$context.sink { [weak localStore] context in
            guard let localStore = localStore else { return }
            localStore.state.value.context = context
        }

        return localStore
    }

    /// Scopes the store to a publisher of stores of more local state and local actions
    ///
    /// - Parameter toLocalState: a function that transforms a publisher of `State` into a publisher of `LocalState`
    /// - Returns: a publisher of stores with its domain (state and action) transformed
    public func publisherScope<P: Publisher, LocalState>(
        state toLocalState: @escaping (AnyPublisher<State, Never>) -> P
    ) -> AnyPublisher<Store<LocalState, Action>, Never>
    where P.Output == LocalState, P.Failure == Never {
        publisherScope(state: toLocalState, action: { $0 })
    }

    func send(_ action: Action) {

        if !isSending {
            synchronousActionsToSend.append(action)
        } else {
            bufferedActions.append(action)
            return
        }

        while !synchronousActionsToSend.isEmpty || !bufferedActions.isEmpty {
            let action =
                !synchronousActionsToSend.isEmpty
                ? synchronousActionsToSend.removeFirst()
                : bufferedActions.removeFirst()

            isSending = true
            let effect = reducer(&state.value, action)
            isSending = false

            var didComplete = false
            let uuid = UUID()

            var isProcessingEffects = true
            let effectCancellable = effect.sink(
                receiveCompletion: { [weak self] _ in
                    didComplete = true
                    self?.effectCancellables[uuid] = nil
                },
                receiveValue: { [weak self] action in
                    if isProcessingEffects {
                        self?.synchronousActionsToSend.append(action)
                    } else {
                        self?.send(action)
                    }
                }
            )
            isProcessingEffects = false

            if !didComplete {
                effectCancellables[uuid] = effectCancellable
            }
        }
    }

    /// Returns a "stateless" store by erasing state to `Void`
    public var stateless: Store<Void, Action> {
        scope(state: { _ in () })
    }

    /// Returns an "actionless" store by erasing action to `Never`
    public var actionless: Store<State, Never> {
        func absurd<A>(_ never: Never) -> A {}
        return scope(state: { $0 }, action: absurd)
    }
}

// MARK: - StorePublisher

/// A publisher of store state
@dynamicMemberLookup
public struct StorePublisher<State>: Publisher {

    // MARK: - Aliases

    public typealias Output = State
    public typealias Failure = Never

    // MARK: - Properties

    public let upstream: AnyPublisher<State, Never>

    // MARK: - Initializers

    init<P>(_ upstream: P) where P: Publisher, Failure == P.Failure, Output == P.Output {
        self.upstream = upstream.eraseToAnyPublisher()
    }

    // MARK: - Publisher

    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        self.upstream.subscribe(subscriber)
    }

    // MARK: - Subscripts

    /// Returns the resulting publisher of a given key path.
    public subscript<LocalState>(
        dynamicMember keyPath: KeyPath<State, LocalState>
    ) -> StorePublisher<LocalState> where LocalState: Equatable {
        .init(self.upstream.map(keyPath).removeDuplicates())
    }
}
