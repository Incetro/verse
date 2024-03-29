//
//  ReducerDebugging.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import EnumKeyPaths
import Dispatch

// MARK: - ActionFormat

/// Determines how the string description of an action should be printed
/// when using the `.debug()` higher-order reducer
public enum ActionFormat {

    /// Prints the action in a single line by only specifying the labels of the associated values:
    ///
    ///     Action.screenA(.row(index:, action: .textChanged(query:)))
    case labelsOnly

    /// Prints the action in a multiline, pretty-printed format, including all the labels of
    /// any associated values, as well as the data held in the associated values:
    ///
    ///     Action.screenA(
    ///         ScreenA.row(
    ///             index: 1,
    ///             action: RowAction.textChanged(
    ///                 query: "Hi"
    ///             )
    ///         )
    ///     )
    case prettyPrint
}

// MARK: - Debug

extension Reducer {

    /// Prints debug messages describing all received actions and state mutations
    ///
    /// Printing is only done in debug (`#if DEBUG`) builds
    ///
    /// - Parameters:
    ///   - prefix: a string with which to prefix all debug messages
    ///   - toDebugEnvironment: a function that transforms an environment into a debug environment by
    ///     describing a print function and a queue to print from. Defaults to a function that ignores
    ///     the environment and returns a default `DebugEnvironment` that uses Swift's `print`
    ///     function and a background queue
    /// - Returns: a reducer that prints debug messages for all received actions
    public func debug(
        _ prefix: String = "",
        actionFormat: ActionFormat = .prettyPrint,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Reducer {
        self.debug(
            prefix,
            state: { $0 },
            action: .self,
            actionFormat: actionFormat,
            environment: toDebugEnvironment
        )
    }

    /// Prints debug messages describing all received actions
    ///
    /// Printing is only done in debug (`#if DEBUG`) builds
    ///
    /// - Parameters:
    ///   - prefix: a string with which to prefix all debug messages
    ///   - toDebugEnvironment: a function that transforms an environment into a debug environment by
    ///     describing a print function and a queue to print from. Defaults to a function that ignores
    ///     the environment and returns a default `DebugEnvironment` that uses Swift's `print`
    ///     function and a background queue
    /// - Returns: a reducer that prints debug messages for all received actions
    public func debugActions(
        _ prefix: String = "",
        actionFormat: ActionFormat = .prettyPrint,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Reducer {
        self.debug(
            prefix,
            state: { _ in () },
            action: .self,
            actionFormat: actionFormat,
            environment: toDebugEnvironment
        )
    }

    /// Prints debug messages describing all received local actions and local state mutations
    ///
    /// Printing is only done in debug (`#if DEBUG`) builds
    ///
    /// - Parameters:
    ///   - prefix: a string with which to prefix all debug messages.
    ///   - toLocalState: a function that filters state to be printed.
    ///   - toLocalAction: a case path that filters actions that are printed.
    ///   - toDebugEnvironment: a function that transforms an environment into a debug environment by
    ///     describing a print function and a queue to print from. Defaults to a function that ignores
    ///     the environment and returns a default `DebugEnvironment` that uses Swift's `print`
    ///     function and a background queue.
    /// - Returns: a reducer that prints debug messages for all received actions.
    public func debug<LocalState, LocalAction>(
        _ prefix: String = "",
        state toLocalState: @escaping (State) -> LocalState,
        action toLocalAction: EnumKeyPath<Action, LocalAction>,
        actionFormat: ActionFormat = .prettyPrint,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Reducer {
        Reducer { state, action, environment in
            let previousState = toLocalState(state)
            let effects = self.run(&state, action, environment)
            guard let localAction = toLocalAction.extract(from: action) else { return effects }
            let nextState = toLocalState(state)
            let debugEnvironment = toDebugEnvironment(environment)
            return .merge(
                .fireAndForget {
                    debugEnvironment.queue.async {
                        let actionOutput =
                            actionFormat == .prettyPrint
                            ? debugOutput(localAction).indent(by: 2)
                            : debugCaseOutput(localAction).indent(by: 2)
                        let stateOutput =
                            LocalState.self == Void.self
                            ? ""
                            : debugDiff(previousState, nextState).map { "\($0)\n" } ?? "  (No state changes)\n"
                        debugEnvironment.printer(
                            """
                            \(prefix.isEmpty ? "" : "\(prefix): ")received action:
                            \(actionOutput)
                            \(stateOutput)
                            """
                        )
                    }
                },
                effects
            )
        }
    }
}

/// An environment for debug-printing reducers
public struct DebugEnvironment {

    // MARK: - Properties

    /// Printing method
    public let printer: (String) -> Void

    /// Debug queue
    public let queue: DispatchQueue

    // MARK: - Initializers

    /// Default initializer
    /// - Parameters:
    ///   - printer: printing method
    ///   - queue: debug queue
    public init(
        printer: @escaping (String) -> Void = { print($0) },
        queue: DispatchQueue
    ) {
        self.printer = printer
        self.queue = queue
    }

    /// Printer initializer
    /// - Parameter printer: printing method
    public init(
        printer: @escaping (String) -> Void = { print($0) }
    ) {
        self.init(printer: printer, queue: _queue)
    }
}

private let _queue = DispatchQueue(
    label: "com.incetro.verse.debug-environment",
    qos: .background
)
