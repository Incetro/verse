//
//  Debouncing.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Combine

// MARK: - Debounce

extension Effect {

    /// Turns an effect into one that can be debounced
    ///
    /// To turn an effect into a debounce-able one you must provide an identifier, which is used to
    /// determine which in-flight effect should be canceled in order to start a new effect. Any
    /// hashable value can be used for the identifier, such as a string, but you can add a bit of
    /// protection against typos by defining a new type that conforms to `Hashable`, such as an empty
    /// struct:
    ///
    ///     case let .textChanged(text):
    ///         struct SearchId: Hashable {}
    ///         return environment.search(text)
    ///             .map(Action.searchResponse)
    ///             .debounce(
    ///                 id: SearchId(),
    ///                 for: 0.5,
    ///                 scheduler: environment.mainQueue
    ///             )
    ///
    /// - Parameters:
    ///   - id: the effect's identifier
    ///   - dueTime: the duration you want to debounce for
    ///   - scheduler: the scheduler you want to deliver the debounced output to
    ///   - options: scheduler options that customize the effect's delivery of elements
    /// - Returns: an effect that publishes events only after a specified time elapses
    public func debounce<S: Scheduler>(
        id: AnyHashable,
        for dueTime: S.SchedulerTimeType.Stride,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Effect {
        Just(())
            .setFailureType(to: Failure.self)
            .delay(for: dueTime, scheduler: scheduler, options: options)
            .flatMap { self }
            .eraseToEffect()
            .cancellable(id: id, cancelInFlight: true)
    }
}
