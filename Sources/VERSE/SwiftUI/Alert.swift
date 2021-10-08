//
//  Alert.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import SwiftUI

// MARK: - AlertState

/// A data type that describes the state of an alert that can be shown to the user. The `Action`
/// generic is the type of actions that can be sent from tapping on a button in the alert.
///
/// This type can be used in your application's state in order to control the presentation or
/// dismissal of alerts. It is preferable to use this API instead of the default SwiftUI API
/// for alerts because SwiftUI uses 2-way bindings in order to control the showing and dismissal
/// of alerts, and that does not play nicely with the VERSE. The library requires
/// that all state mutations happen by sending an action so that a reducer can handle that logic,
/// which greatly simplifies how data flows through your application, and gives you instant
/// testability on all parts of your application.
///
/// To use this API, you model all the alert actions in your domain's action enum:
///
///     // MARK: - AppAction
///
///     enum AppAction: Equatable {
///
///         case cancelTapped
///         case confirmTapped
///         case deleteTapped
///
///         // Your other actions
///     }
///
/// And you model the state for showing the alert in your domain's state, and it can start off `nil`:
///
///     // MARK: - AppState
///
///     struct AppState: Equatable {
///         var alert = AlertState<AppAction>?
///         // Your other state
///     }
///
/// Then, in the reducer you can construct an `AlertState` value to represent the alert you want
/// to show to the user:
///
///     let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, env in
///         switch action
///             case .cancelTapped:
///                 state.alert = nil
///                 return .none
///
///             case .confirmTapped:
///                 state.alert = nil
///                 // Do deletion logic...
///
///             case .deleteTapped:
///                 state.alert = .init(
///                     title: TextState("Delete"),
///                     message: TextState("Are you sure you want to delete this? It cannot be undone."),
///                     primaryButton: .default(TextState("Confirm"), send: .confirmTapped),
///                     secondaryButton: .cancel()
///                 )
///             return .none
///         }
///     }
///
/// And then, in your view you can use the `.alert(_:send:dismiss:)` method on `View` in order
/// to present the alert in a way that works best with the VERSE:
///
///     Button("Delete") { viewStore.send(.deleteTapped) }
///         .alert(
///             self.store.scope(state: \.alert),
///             dismiss: .cancelTapped
///         )
///
/// This makes your reducer in complete control of when the alert is shown or dismissed, and makes
/// it so that any choice made in the alert is automatically fed back into the reducer so that you
/// can handle its logic.
///
/// Even better, you can instantly write tests that your alert behavior works as expected:
///
///     let store = TestStore(
///         initialState: AppState(),
///         reducer: appReducer,
///         environment: .mock
///     )
///
///     store.send(.deleteTapped) {
///         $0.alert = .init(
///             title: TextState("Delete"),
///             message: TextState("Are you sure you want to delete this? It cannot be undone."),
///             primaryButton: .default(TextState("Confirm"), send: .confirmTapped),
///             secondaryButton: .cancel(send: .cancelTapped)
///         )
///     }
///     store.send(.deleteTapped) {
///         $0.alert = nil
///         // Also verify that delete logic executed correctly
///     }
///
public struct AlertState<Action> {

    // MARK: - Properties

    /// Unique identifier
    public let id = UUID()

    /// Alert message
    public var message: TextState?

    /// Main button
    public var primaryButton: Button?

    /// Secondary button
    public var secondaryButton: Button?

    /// Alert title string
    public var title: TextState

    // MARK: - Initializers

    /// Dismissal initializer
    /// - Parameters:
    ///   - title: alert title string
    ///   - message: alert message
    ///   - dismissButton: the main button in the alert
    public init(
        title: TextState,
        message: TextState? = nil,
        dismissButton: Button? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryButton = dismissButton
    }

    /// Two-buttons initializer
    /// - Parameters:
    ///   - title: alert title string
    ///   - message: alert message string
    ///   - primaryButton: a main button
    ///   - secondaryButton: a secondary button
    public init(
        title: TextState,
        message: TextState? = nil,
        primaryButton: Button,
        secondaryButton: Button
    ) {
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
    }

    // MARK: - Button

    public struct Button {

        // MARK: - Properties

        public var action: Action?
        public var type: `Type`

        // MARK: - Static

        /// Returns `cancel` button instance
        /// - Parameters:
        ///   - label: button title
        ///   - action: button action
        /// - Returns: `cancel` button instance
        public static func cancel(
            _ label: TextState,
            send action: Action? = nil
        ) -> Self {
            Self(action: action, type: .cancel(label: label))
        }

        /// Returns `cancel` button instance
        /// - Parameters:
        ///   - action: button action
        /// - Returns: `cancel` button instance
        public static func cancel(
            send action: Action? = nil
        ) -> Self {
            Self(action: action, type: .cancel(label: nil))
        }

        /// Returns `default` button instance
        /// - Parameters:
        ///   - label: button title
        ///   - action: button action
        /// - Returns: `default` button instance
        public static func `default`(
            _ label: TextState,
            send action: Action? = nil
        ) -> Self {
            Self(action: action, type: .default(label: label))
        }

        /// Returns `destructive` button instance
        /// - Parameters:
        ///   - label: button title
        ///   - action: button action
        /// - Returns: `destructive` button instance
        public static func destructive(
            _ label: TextState,
            send action: Action? = nil
        ) -> Self {
            Self(action: action, type: .destructive(label: label))
        }

        // MARK: - Type

        public enum `Type` {
            case cancel(label: TextState?)
            case `default`(label: TextState)
            case destructive(label: TextState)
        }
    }
}

// MARK: - View

extension View {

    /// Displays an alert when then store's state becomes non-`nil`, and dismisses it when it becomes `nil`
    ///
    /// - Parameters:
    ///   - store: a store that describes if the alert is shown or dismissed
    ///   - dismissal: an action to send when the alert is dismissed through non-user actions, such
    ///     as when an alert is automatically dismissed by the system. Use this action to `nil` out
    ///     the associated alert state.
    public func alert<Action>(
        _ store: Store<AlertState<Action>?, Action>,
        dismiss: Action
    ) -> some View {
        WithViewStore(store, removeDuplicates: { $0?.id == $1?.id }) { viewStore in
            alert(item: viewStore.binding(send: dismiss)) { state in
                state.toSwiftUI(send: viewStore.send)
            }
        }
    }
}

// MARK: - CustomDebugOutputConvertible

extension AlertState: CustomDebugOutputConvertible {

    public var debugOutput: String {
        let fields = (
            title: self.title,
            message: self.message,
            primaryButton: self.primaryButton,
            secondaryButton: self.secondaryButton
        )
        return "\(Self.self)\(VERSE.debugOutput(fields))"
    }
}

// MARK: - Equatable

extension AlertState: Equatable where Action: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title
            && lhs.message == rhs.message
            && lhs.primaryButton == rhs.primaryButton
            && lhs.secondaryButton == rhs.secondaryButton
    }
}

// MARK: - Hashable

extension AlertState: Hashable where Action: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.title)
        hasher.combine(self.message)
        hasher.combine(self.primaryButton)
        hasher.combine(self.secondaryButton)
    }
}

// MARK: - Other

extension AlertState: Identifiable {}

extension AlertState.Button.`Type`: Equatable {}
extension AlertState.Button: Equatable where Action: Equatable {}

extension AlertState.Button.`Type`: Hashable {}
extension AlertState.Button: Hashable where Action: Hashable {}

extension AlertState.Button {

    func toSwiftUI(send: @escaping (Action) -> Void) -> SwiftUI.Alert.Button {
        let action = { if let action = self.action { send(action) } }
        switch self.type {
        case let .cancel(.some(label)):
            return .cancel(Text(label), action: action)
        case .cancel(.none):
            return .cancel(action)
        case let .default(label):
            return .default(Text(label), action: action)
        case let .destructive(label):
            return .destructive(Text(label), action: action)
        }
    }
}

extension AlertState {

    fileprivate func toSwiftUI(send: @escaping (Action) -> Void) -> SwiftUI.Alert {
        if let primaryButton = primaryButton, let secondaryButton = secondaryButton {
            return SwiftUI.Alert(
                title: Text(title),
                message: message.map { Text($0) },
                primaryButton: primaryButton.toSwiftUI(send: send),
                secondaryButton: secondaryButton.toSwiftUI(send: send)
            )
        } else {
            return SwiftUI.Alert(
                title: Text(title),
                message: message.map { Text($0) },
                dismissButton: primaryButton?.toSwiftUI(send: send)
            )
        }
    }
}
