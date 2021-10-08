//
//  Create.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Combine
import Darwin

// MARK: - DemandBuffer

private class DemandBuffer<S: Subscriber> {

    // MARK: - Demand

    struct Demand {

        /// Processed demand
        var processed: Subscribers.Demand = .none

        /// Requested demand
        var requested: Subscribers.Demand = .none

        /// Sent demand
        var sent: Subscribers.Demand = .none
    }

    // MARK: - Properties

    /// Current buffer sequence
    private var buffer = [S.Input]()

    /// Subscriber instance
    private let subscriber: S

    /// Completion result
    private var completion: Subscribers.Completion<S.Failure>?

    /// Current state
    private var demandState = Demand()

    /// Locker instance
    private let lock: os_unfair_lock_t

    // MARK: - Initializers

    /// Default initializer
    /// - Parameter subscriber: subscriber instance
    init(subscriber: S) {
        self.subscriber = subscriber
        self.lock = os_unfair_lock_t.allocate(capacity: 1)
        self.lock.initialize(to: os_unfair_lock())
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    // MARK: - Useful

    /// Buffer the given value
    /// - Parameter value: some input value
    /// - Returns: subscribers demand
    func buffer(value: S.Input) -> Subscribers.Demand {
        precondition(self.completion == nil, "How could a completed publisher sent values?! Beats me 🤷‍♂️")
        switch demandState.requested {
        case .unlimited:
            return subscriber.receive(value)
        default:
            buffer.append(value)
            return flush()
        }
    }

    /// Completes current work
    /// - Parameter completion: completion type
    func complete(completion: Subscribers.Completion<S.Failure>) {
        precondition(self.completion == nil, "Completion have already occurred, which is quite awkward 🥺")
        self.completion = completion
        _ = flush()
    }

    /// Return a new demand using the given demand
    /// - Parameter demand: input demand
    /// - Returns: a new demand using the given demand
    func demand(_ demand: Subscribers.Demand) -> Subscribers.Demand {
        flush(adding: demand)
    }

    // MARK: - Private

    private func flush(adding newDemand: Subscribers.Demand? = nil) -> Subscribers.Demand {
        lock.sync {
            if let newDemand = newDemand {
                demandState.requested += newDemand
            }
            /// If buffer isn't ready for flushing, return immediately
            guard demandState.requested > 0 || newDemand == Subscribers.Demand.none else { return .none }
            while !buffer.isEmpty && demandState.processed < demandState.requested {
                demandState.requested += subscriber.receive(buffer.remove(at: 0))
                demandState.processed += 1
            }
            if let completion = completion {
                /// Completion event was already sent
                buffer = []
                demandState = .init()
                self.completion = nil
                subscriber.receive(completion: completion)
                return .none
            }
            let sentDemand = demandState.requested - demandState.sent
            demandState.sent += sentDemand
            return sentDemand
        }
    }
}

// MARK: - AnyPublisher

extension AnyPublisher {

    /// Effect initializer
    /// - Parameter callback: "Create" callback closure
    private init(_ callback: @escaping (Effect<Output, Failure>.Subscriber) -> Cancellable) {
        self = Publishers.Create(callback: callback).eraseToAnyPublisher()
    }

    /// Static method Effect initializer
    /// - Parameter factory: "Create" callback closure
    /// - Returns: necessary publisher instance
    static func create(
        _ factory: @escaping (Effect<Output, Failure>.Subscriber) -> Cancellable
    ) -> AnyPublisher<Output, Failure> {
        AnyPublisher(factory)
    }
}

// MARK: - Create

extension Publishers {

    fileprivate class Create<Output, Failure: Swift.Error>: Publisher {

        // MARK: - Properties

        /// "Create" callback closure
        private let callback: (Effect<Output, Failure>.Subscriber) -> Cancellable

        // MARK: - Initializers

        /// Defaul initializer
        /// - Parameter callback: "Create" callback closure
        init(callback: @escaping (Effect<Output, Failure>.Subscriber) -> Cancellable) {
            self.callback = callback
        }

        // MARK: - Publisher

        /// Attaches the specified subscriber to this publisher.
        ///
        /// Implementations of ``Publisher`` must implement this method.
        ///
        /// The provided implementation of ``Publisher/subscribe(_:)-4u8kn``calls this method.
        ///
        /// - Parameter subscriber: The subscriber to attach to this ``Publisher``, after which it can receive values.
        func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            subscriber.receive(subscription: Subscription(callback: callback, downstream: subscriber))
        }
    }
}

extension Publishers.Create {

    fileprivate class Subscription<Downstream: Subscriber>: Combine.Subscription
    where Output == Downstream.Input, Failure == Downstream.Failure {

        // MARK: - Properties

        /// Currently processing buffer. We use it to
        /// implement complete "Create" publisher logic
        private let buffer: DemandBuffer<Downstream>

        /// Current cancellable instance
        private var cancellable: Cancellable?

        // MARK: - Initializers

        /// Default initializer
        /// - Parameters:
        ///   - callback: "Create" callback closure
        ///   - downstream: downstream publisher instance
        init(
            callback: @escaping (Effect<Output, Failure>.Subscriber) -> Cancellable,
            downstream: Downstream
        ) {
            self.buffer = DemandBuffer(subscriber: downstream)
            self.cancellable = callback(
                .init(
                    send: { [weak self] in
                        _ = self?.buffer.buffer(value: $0)
                    },
                    complete: { [weak self] in
                        self?.buffer.complete(completion: $0)
                    }
                )
            )
        }

        // MARK: - Subscription

        func request(_ demand: Subscribers.Demand) {
            _ = self.buffer.demand(demand)
        }

        func cancel() {
            self.cancellable?.cancel()
        }
    }
}

// MARK: - CustomStringConvertible

extension Publishers.Create.Subscription: CustomStringConvertible {
    var description: String {
        return "Create.Subscription<\(Output.self), \(Failure.self)>"
    }
}

// MARK: - Effect

extension Effect {

    /// Effect subscriber structure helper
    public struct Subscriber {

        // MARK: - Properties

        /// Sender closure
        private let _send: (Output) -> Void

        /// Completion closure
        private let _complete: (Subscribers.Completion<Failure>) -> Void

        // MARK: - Initializers

        /// Default initializer
        /// - Parameters:
        ///   - send: sender closure
        ///   - complete: completion closure
        init(
            send: @escaping (Output) -> Void,
            complete: @escaping (Subscribers.Completion<Failure>) -> Void
        ) {
            self._send = send
            self._complete = complete
        }

        // MARK: - Useful

        /// Sends the given value
        /// - Parameter value: some value
        public func send(_ value: Output) {
            self._send(value)
        }

        /// Send completion event
        /// - Parameter completion: completion event
        public func send(completion: Subscribers.Completion<Failure>) {
            self._complete(completion)
        }
    }
}
