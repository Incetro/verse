import XCTest

@testable import VERSE

final class IdentifiedArrayTests: XCTestCase {

    func testIdSubscript() {
        struct User: Equatable, Identifiable {
            let id: Int
            var name: String
        }

        let array: IdentifiedArray = [User(id: 1, name: "Fame")]

        XCTAssertEqual(array[id: 1], .some(User(id: 1, name: "Fame")))
    }

    func testRemoveId() {
        struct User: Equatable, Identifiable {
            let id: Int
            var name: String
        }

        var array: IdentifiedArray = [User(id: 1, name: "Fame")]

        XCTAssertEqual(array.remove(id: 1), User(id: 1, name: "Fame"))
        XCTAssertEqual(array, [])
    }

    func testInsert() {
        struct User: Equatable, Identifiable {
            let id: Int
            var name: String
        }

        var array: IdentifiedArray = [User(id: 1, name: "Fame")]

        array.insert(User(id: 2, name: "Fame Jr."), at: 0)
        XCTAssertEqual(array, [User(id: 2, name: "Fame Jr."), User(id: 1, name: "Fame")])
    }

    func testInsertContentsOf() {
        struct User: Equatable, Identifiable {
            let id: Int
            var name: String
        }

        var array: IdentifiedArray = [User(id: 1, name: "Fame")]

        array.insert(contentsOf: [User(id: 3, name: "Fame Sr."), User(id: 2, name: "Fame Jr.")], at: 0)
        XCTAssertEqual(
            array,
            [User(id: 3, name: "Fame Sr."), User(id: 2, name: "Fame Jr."), User(id: 1, name: "Fame")]
        )
    }

    func testRemoveAt() {
        struct User: Equatable, Identifiable {
            let id: Int
            var name: String
        }

        var array: IdentifiedArray = [
            User(id: 3, name: "Fame Sr."),
            User(id: 2, name: "Fame Jr."),
            User(id: 1, name: "Fame"),
        ]

        array.remove(at: 1)
        XCTAssertEqual(array, [User(id: 3, name: "Fame Sr."), User(id: 1, name: "Fame")])
    }

    func testRemoveAllWhere() {
        struct User: Equatable, Identifiable {
            let id: Int
            var name: String
        }

        var array: IdentifiedArray = [
            User(id: 3, name: "Fame Sr."),
            User(id: 2, name: "Fame Jr."),
            User(id: 1, name: "Fame"),
        ]

        array.removeAll(where: { $0.name.starts(with: "Fame ") })
        XCTAssertEqual(array, [User(id: 1, name: "Fame")])
    }

    func testRemoveAtOffsets() {
        struct User: Equatable, Identifiable {
            let id: Int
            var name: String
        }

        var array: IdentifiedArray = [
            User(id: 3, name: "Fame Sr."),
            User(id: 2, name: "Fame Jr."),
            User(id: 1, name: "Fame"),
        ]

        array.remove(atOffsets: [0, 2])
        XCTAssertEqual(array, [User(id: 2, name: "Fame Jr.")])
    }

    func testMoveFromOffsets() {
        struct User: Equatable, Identifiable {
            let id: Int
            var name: String
        }

        var array: IdentifiedArray = [
            User(id: 3, name: "Fame Sr."),
            User(id: 2, name: "Fame Jr."),
            User(id: 1, name: "Fame"),
        ]

        array.move(fromOffsets: [0], toOffset: 2)
        XCTAssertEqual(
            array,
            [User(id: 2, name: "Fame Jr."), User(id: 3, name: "Fame Sr."), User(id: 1, name: "Fame")]
        )
    }

    func testReplaceSubrange() {
        struct User: Equatable, Identifiable {
            let id: Int
            var name: String
        }

        var array: IdentifiedArray = [
            User(id: 3, name: "Fame Sr."),
            User(id: 2, name: "Fame Jr."),
            User(id: 1, name: "Fame"),
            User(id: 2, name: "Fame Jr."),
        ]

        array.replaceSubrange(
            0...1,
            with: [
                User(id: 4, name: "Flob IV"),
                User(id: 5, name: "Flob V"),
            ]
        )

        XCTAssertEqual(
            array,
            [
                User(id: 4, name: "Flob IV"), User(id: 5, name: "Flob V"), User(id: 1, name: "Fame"),
                User(id: 2, name: "Fame Jr."),
            ]
        )
    }

    struct ComparableValue: Comparable, Identifiable {
        let id: Int
        let value: Int

        static func < (lhs: ComparableValue, rhs: ComparableValue) -> Bool {
            return lhs.value < rhs.value
        }
    }

    func testSortBy() {
        var array: IdentifiedArray = [
            ComparableValue(id: 1, value: 100),
            ComparableValue(id: 2, value: 50),
            ComparableValue(id: 3, value: 75),
        ]

        array.sort { $0.value < $1.value }

        XCTAssertEqual([2, 3, 1], array.ids)
        XCTAssertEqual(
            [
                ComparableValue(id: 2, value: 50),
                ComparableValue(id: 3, value: 75),
                ComparableValue(id: 1, value: 100),
            ], array)
    }

    func testSort() {
        var array: IdentifiedArray = [
            ComparableValue(id: 1, value: 100),
            ComparableValue(id: 2, value: 50),
            ComparableValue(id: 3, value: 75),
        ]

        array.sort()

        XCTAssertEqual([2, 3, 1], array.ids)
        XCTAssertEqual(
            [
                ComparableValue(id: 2, value: 50),
                ComparableValue(id: 3, value: 75),
                ComparableValue(id: 1, value: 100),
            ], array)

    }

    // Account for randomness API changes in Swift 5.3 (https://twitter.com/mbrandonw/status/1262388756847505410)
    // TODO: Try swapping out the LCRNG for a Xoshiro generator
    #if swift(>=5.3)
    func testShuffle() {
        struct User: Equatable, Identifiable {
            let id: Int
            var name: String
        }

        var array: IdentifiedArray = [
            User(id: 1, name: "Fame"),
            User(id: 2, name: "Fame Jr."),
            User(id: 3, name: "Fame Sr."),
            User(id: 4, name: "Foo Jr."),
            User(id: 5, name: "Bar Jr."),
        ]
        var lcrng = LCRNG(seed: 0)
        array.shuffle(using: &lcrng)
        XCTAssertEqual(
            [
                User(id: 1, name: "Fame"),
                User(id: 3, name: "Fame Sr."),
                User(id: 5, name: "Bar Jr."),
                User(id: 4, name: "Foo Jr."),
                User(id: 2, name: "Fame Jr."),
            ],
            array.elements
        )
        XCTAssertEqual([1, 3, 5, 4, 2], array.ids)
    }
    #endif

    func testReverse() {
        var array: IdentifiedArray = [
            ComparableValue(id: 1, value: 100),
            ComparableValue(id: 2, value: 50),
            ComparableValue(id: 3, value: 75),
        ]

        array.reverse()

        XCTAssertEqual([3, 2, 1], array.ids)
        XCTAssertEqual(
            [
                ComparableValue(id: 3, value: 75),
                ComparableValue(id: 2, value: 50),
                ComparableValue(id: 1, value: 100),
            ], array)
    }
}
