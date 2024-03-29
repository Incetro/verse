//
//  Throttling.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Combine
import Dispatch

// MARK: - Throttle

extension Effect {

    /// Turns an effect into one that can be throttled
    ///
    /// - Parameters:
    ///   - id: the effect's identifier
    ///   - interval: the interval at which to find and emit the most recent element, expressed in
    ///     the time system of the scheduler
    ///   - scheduler: the scheduler you want to deliver the throttled output to
    ///   - latest: a boolean value that indicates whether to publish the most recent element. If
    ///     `false`, the publisher emits the first element received during the interval
    /// - Returns: an effect that emits either the most-recent or first element received during the
    ///   specified interval
    public func throttle<S>(
        id: AnyHashable,
        for interval: S.SchedulerTimeType.Stride,
        scheduler: S,
        latest: Bool = false
    ) -> Effect where S: Scheduler {
        flatMap { value -> AnyPublisher<Output, Failure> in

            guard let throttleTime = throttleTimes[id] as? S.SchedulerTimeType else {
                throttleTimes[id] = scheduler.now
                throttleValues[id] = nil
                return Just(value)
                    .setFailureType(to: Failure.self)
                    .eraseToAnyPublisher()
            }

            guard throttleTime.distance(to: scheduler.now) < interval else {
                throttleTimes[id] = scheduler.now
                throttleValues[id] = nil
                return Just(value)
                    .setFailureType(to: Failure.self)
                    .eraseToAnyPublisher()
            }

            let value = latest ? value : (throttleValues[id] as? Output ?? value)
            throttleValues[id] = value

            return Just(value)
                .delay(
                    for: scheduler.now.distance(
                        to: throttleTime.advanced(by: interval)
                    ),
                    scheduler: scheduler
                )
                .setFailureType(to: Failure.self)
                .eraseToAnyPublisher()
        }
        .eraseToEffect()
        .cancellable(id: id, cancelInFlight: true)
    }

    /// Throttles an effect so that it only publishes one output per given interval.
    ///
    /// A convenience for calling ``Effect/throttle(id:for:scheduler:latest:)`` with a static
    /// type as the effect's unique identifier.
    ///
    /// - Parameters:
    ///   - id: the effect's identifier.
    ///   - interval: the interval at which to find and emit the most recent element, expressed in
    ///     the time system of the scheduler.
    ///   - scheduler: the scheduler you want to deliver the throttled output to.
    ///   - latest: a boolean value that indicates whether to publish the most recent element. If
    ///     `false`, the publisher emits the first element received during the interval.
    /// - Returns: an effect that emits either the most-recent or first element received during the
    ///   specified interval.
    public func throttle<S>(
        id: Any.Type,
        for interval: S.SchedulerTimeType.Stride,
        scheduler: S,
        latest: Bool
    ) -> Effect where S: Scheduler {
        throttle(id: ObjectIdentifier(id), for: interval, scheduler: scheduler, latest: latest)
    }

    /// Turns an effect into one that can be sampled
    ///
    /// - Parameters:
    ///   - id: the effect's identifier
    ///   - interval: the interval at which to find and emit the most recent element, expressed in
    ///     the time system of the scheduler
    ///   - scheduler: the scheduler you want to deliver the throttled output to
    /// - Returns: an effect that emits either the most-recent or first element received during the
    ///   specified interval
    public func sample<S>(
        id: AnyHashable,
        for interval: S.SchedulerTimeType.Stride,
        scheduler: S
    ) -> Effect where S: Scheduler {
        throttle(id: id, for: interval, scheduler: scheduler, latest: true)
    }

    /// Turns an effect into one that can be sampled
    ///
    /// A convenience for calling ``Effect/sample(id:for:scheduler:)`` with a static
    /// type as the effect's unique identifier.
    ///
    /// - Parameters:
    ///   - id: the effect's identifier
    ///   - interval: the interval at which to find and emit the most recent element, expressed in
    ///     the time system of the scheduler
    ///   - scheduler: the scheduler you want to deliver the throttled output to
    /// - Returns: an effect that emits either the most-recent or first element received during the
    ///   specified interval
    public func sample<S>(
        id: Any.Type,
        for interval: S.SchedulerTimeType.Stride,
        scheduler: S
    ) -> Effect where S: Scheduler {
        throttle(id: id, for: interval, scheduler: scheduler, latest: true)
    }
}

// MARK: - Variables

private var throttleTimes: [AnyHashable: Any] = [:]
private var throttleValues: [AnyHashable: Any] = [:]
