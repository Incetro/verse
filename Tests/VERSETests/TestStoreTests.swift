import Combine
import VERSE
import XCTest

class TestStoreTests: XCTestCase {

    func testEffectConcatenation() {

        struct State: Equatable {}

        enum Action: Equatable {
            case a, b1, b2, b3, c1, c2, c3, d
        }

        let testScheduler = DispatchQueue.test

        let reducer = Reducer<State, Action, AnySchedulerOf<DispatchQueue>> { _, action, scheduler in
            switch action {
            case .a:
                return .merge(
                    Effect.concatenate(.init(value: .b1), .init(value: .c1))
                        .delay(for: 1, scheduler: scheduler)
                        .eraseToEffect(),
                    Empty(completeImmediately: false)
                        .eraseToEffect()
                        .cancellable(id: 1)
                )
            case .b1:
                return
                    Effect
                    .concatenate(.init(value: .b2), .init(value: .b3))
            case .c1:
                return
                    Effect
                    .concatenate(.init(value: .c2), .init(value: .c3))
            case .b2, .b3, .c2, .c3:
                return .none

            case .d:
                return .cancel(id: 1)
            }
        }

        let store = TestStore(
            initialState: State(),
            reducer: reducer,
            environment: testScheduler.eraseToAnyScheduler()
        )

        store.send(.a)

        testScheduler.advance(by: 1)

        store.receive(.b1)
        store.receive(.b2)
        store.receive(.b3)

        store.receive(.c1)
        store.receive(.c2)
        store.receive(.c3)

        store.send(.d)
    }
}
