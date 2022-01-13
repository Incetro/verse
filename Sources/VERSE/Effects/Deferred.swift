//
//  Deferred.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Combine

// MARK: - Deferred

extension Effect {

    /// Returns an effect that will be executed after given interval
    ///
    /// ```
    /// case let .textChanged(text):
    ///     return environment.search(text)
    ///         .deferred(for: 0.5, scheduler: environment.mainQueue)
    ///         .map(Action.toast)
    /// ```
    ///
    /// - Parameters:
    ///     - upstream: the effect you want to defer.
    ///     - dueTime: The duration you want to defer for.
    ///     - scheduler: The scheduler you want to deliver the defer output to.
    ///     - options: Scheduler options that customize the effect's delivery of elements.
    /// - Returns: An effect that will be executed after `dueTime`
    public func deferred<S: Scheduler>(
        for dueTime: S.SchedulerTimeType.Stride,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Effect {
        Just(())
            .setFailureType(to: Failure.self)
            .delay(for: dueTime, scheduler: scheduler, options: options)
            .flatMap { receive(on: scheduler) }
            .eraseToEffect()
    }
}
