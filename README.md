# VERSE
VERSE is a library for building versatile iOS / tvOS / macOS / watchOS applications in a very FAST, flexible, consistent, testable and independent way. You can compose VERSE components in complex modules, regardless of whether you have design and backend or not. In short, you can write your apps incredibly fast and get all the benefits above without losing the quality of the code.

* [What is VERSE?](#what-is-verse)
* [Examples](#examples)
* [Basic usage](#basic-usage)
* [Debugging](#debugging)
* [Requirements](#requirements)
* [Installation](#installation)
* [Other architectures](#other-architectures)

## What is VERSE?
VERSE gives you a set of tools and components which you can use to build production-ready applications without boilreplate code and even without necessity of waiting for design / backend parts. VERSE is a system and if you follow it you will get an opportunity to test your business ideas even faster and build brilliant app architecture.

VERSE based on several fundamental ideas:

* **State management**.
Manage the state of your apps using simple value types. You can share state across many screens and observe changes of the same state between them.

* **Composition**.
Compose small components into bigger ones. Develop isolated modules and use them to form complex features.

* **Effects**.
Certain parts of the application can communicate with outside world in the most testable and beautiful way possible.

* **Testability**.
Test your business logic with various test options and be sure that your app is solid and stable.

* **Compactness**.
Implement all of the above in a consistent and simplest way possible.

## Examples

We developed lots of examples called [verse-university](https://github.com/Incetro/verse-university) that demonstrates how to solve real-life problems with the VERSE. We divided example apps on several categories:

* Beginner
* Elementary
* Pre-Intermediate
* Intermediate
* Upper-Intermediate
* Advanced
* Proficient

Yep, the same as English Level Scale :)

Moreover, we created sustainable and production-like applications that shows how to implement real modern app with VERSE and SwiftUI.

### Weather
App demonstrates how to use VERSE in such cases as:
1. Location management
2. Searching
3. Realtime updates

### Dews
Our application that aggregates interesting and trending news in Development / Design / Technologies from great web-resources. Here we shows:
1. Work with text transformations
2. Shared global settings
3. Appearance changing

### Voice Memos
You can learn some minor but important concepts:
1. Recursive modules
2. Audio recording
3. Audio playing
4. Timers
5. Manageable list rows behaviour

### Meter
A basic application that interacts with Core Motion:
1. Device motion updates
2. Native bridging from Core Motion to VERSE
3. Permanent events processing

## Basic usage

Every feature / module based on main components:

* **State**: a type that describes the data your feature needs to perform its logic and render its UI
* **Action**: a type that represents all of the actions that can happen in your feature, such as user actions, notifications, events, service calls, network requests and more
* **Environment**: a type that holds any dependencies the feature needs, such as API clients, analytics clients, etc.
* **Reducer**: a function that describes how to evolve the current state of the app to the next state given an action. The reducer is also responsible for returning any effects that should be run, such as API requests, timers, observers, etc., which can be done by returning an Effect value.
* **Store**: the runtime that actually drives your feature. You send all user actions to the store so that the store can run the reducer and effects, and you can observe state changes in the store so that you can update UI
* **Composer**: something like DI container that manages all dependency injections in the feature
* **Services**: business logic wrapped in a simple and understadable concept: every business action returns AnyPublisher as a result

As a basic example, our feature will implement Rubick's Cube scrambler. You can press on the "Scramble" button and generate a new one, also you can move between them by tapping "next" and "prev" buttons. All of them will be generated by the ScrambleService that shows how to work with concrete business features similar to network requests.

The state of our feature will contain current scramble string:

```swift
// MARK: - ScramblerState

/// `Scrambler` module state
///
/// Basically, `ScramblerState` is a type that describes the data
/// `Scrambler` feature needs to perform its logic and render its UI.
struct ScramblerState: Equatable {

    // MARK: - Properties

    /// Current scramble string
    var scramble: String?

    /// Current scramble moves count
    var currentScrambleLength = 10

    /// True if we are waiting for service response
    var isScrambleRequestInFlight = false
}
```

Next we should describe actions of our module. There are some plain and obvious actions that we can do inside our feature and actions that occurs when we interact with some business services:

```swift
// MARK: - ScramblerAction

/// All available `Scrambler` module actions.
///
/// It's a type that represents all of the actions that can happen in `Scrambler` feature,
/// such as user actions, notifications, event sources and more.
///
/// We have some actions in the feature. There are the obvious actions,
/// such as tapping some button, holding another button, or changing a slider value.
/// But there are also some slightly non-obvious ones, such as the action of the user dismissing the alert,
/// and the action that occurs when we receive a response from the fact API request.
public enum ScramblerAction: Equatable {

    // MARK: - Cases

    case plusButtonTapped
    case minusButtonTapped
    case generateButtonTapped
    case scrambleService(Result<ScrambleServiceAction, Never>)
}

```

You may notice that we have `ScrambleServiceAction` in the case above. Let's see how we can create services which drives our business logic. We declare the interface `ScrambleService` and its implementation `ScrambleServiceImplementation`:

```swift
import Combine
import Foundation

// MARK: - ScrambleServiceAction

public enum ScrambleServiceAction: Equatable {
    case scramble(String)
}

// MARK: - ScrambleService

public protocol ScrambleService {

    /// Obtain a random scramble
    ///
    /// - Parameters:
    ///   - length: scramble length (moves count)
    func generateScramble(length: Int) -> AnyPublisher<String, Never>
}

// MARK: - ScrambleServiceImplementation

final class ScrambleServiceImplementation {

    // MARK: - Private

    private func scramble(length: Int) -> String {

        let notations = ["F", "B", "R", "U", "D", "L"].map {
            [$0, $0 + "'", $0 + "2"]
        }

        var previousFace = 0
        var randomFace = Int(arc4random_uniform(6))
        var result = ""

        for i in 0..<length {
            while previousFace == randomFace {
                randomFace = Int(arc4random_uniform(6))
            }
            previousFace = randomFace
            let randomTurn = Int(arc4random_uniform(3))
            let notation = notations[randomFace][randomTurn]
            if i == 0 {
                result += notation
            } else {
                result += " \(notation)"
            }
        }
        return result
    }
}

// MARK: - ScrambleService

extension ScrambleServiceImplementation: ScrambleService {

    public func generateScramble(length: Int) -> AnyPublisher<String, Never> {
        Future { completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                completion(.success(self.scramble(length: length)))
            }
        }.eraseToAnyPublisher()
    }
}
```

Next we model the environment of dependencies this feature needs to do its job. In particular, to generate a new scramble we need to inject `ScrambleService`  that encapsulates scramble generation logic.

```swift
// MARK: - ScramblerEnvironment

/// `Scrambler` module environment.
///
/// `Environment` is a type that holds any dependencies the feature needs,
/// such as API clients, analytics clients, etc.
struct ScramblerEnvironment {

    // MARK: - Properties

    /// ScrambleService instance
    let scrambleService: ScrambleService
}
```

Next, we implement a reducer that implements the logic for this module. It's a function that describes how to evolve the current `ScramblerState` to the next state given an action. The `ScramblerReducer` is also responsible for returning any effects that should be run, such as API requests, which can be done by returning an `Effect` value

```swift
// MARK: - Reducer

/// A `Scrambler` module reducer
///
/// It's a function that describes how to evolve the current `ScramblerState` to the next state given an action.
/// The `ScramblerReducer` is also responsible for returning any effects that should be run, such as API requests,
/// which can be done by returning an `Effect` value
///
/// - Note: The thread on which effects output is important. An effect's output is immediately sent
///   back into the store, and `Store` is not thread safe. This means all effects must receive
///   values on the same thread, **and** if the `Store` is being used to drive UI then all output
///   must be on the main thread. You can use the `Publisher` method `receive(on:)` for make the
///   effect output its values on the thread of your choice.
let scramblerReducer = Reducer<ScramblerState, ScramblerAction, ScramblerEnvironment> { state, action, environment in
    switch action {
    case .plusButtonTapped where !state.isScrambleRequestInFlight:
        state.currentScrambleLength += 1
        return Effect(value: ScramblerAction.generateButtonTapped)
    case .minusButtonTapped where !state.isScrambleRequestInFlight:
        state.currentScrambleLength -= 1
        return Effect(value: ScramblerAction.generateButtonTapped)
    case .generateButtonTapped:
        state.isScrambleRequestInFlight = true
        return environment
            .scrambleService
            .generateScramble(length: state.currentScrambleLength)
            .map(ScrambleServiceAction.scramble)
            .catchToEffect(ScramblerAction.scrambleService)
    case .scrambleService(.success(.scramble(let scramble))):
        state.scramble = scramble
        state.isScrambleRequestInFlight = false
        return .none
    default:
        return .none
    }
}
```

And then finally we define the view that displays the feature. It works with a Store<AppState, AppAction> so that it can send actions, observe all changes to the state and re-render it.

```swift

// MARK: - ScramblerView

/// A visual representation of `Scrambler` module.
/// Here we define the view that displays the feature.
/// It holds onto a `Store<ScramblerState, ScramblerAction>` so that it can observe
/// all changes to the state and re-render, and we can send all user actions
/// to the store so that state changes.
struct ScramblerView: View {

    // MARK: - Properties

    /// `Scrambler` module `Store` instance
    private let store: Store<ScramblerState, ScramblerAction>

    // MARK: - Initializers

    /// Default initializer
    /// - Parameters:
    ///   - store: ScramblerStore instance
    init(store: Store<ScramblerState, ScramblerAction>) {
        self.store = store
    }

    // MARK: - View

    var body: some View {
        WithViewStore(store) { viewStore in
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                VStack {
                    Spacer()
                    if viewStore.isScrambleRequestInFlight {
                        ProgressView()
                    } else {
                        Text(viewStore.scramble ?? "Tap anywhere to generate a new scramble")
                            .font(.system(size: 27).monospacedDigit())
                            .bold()
                            .padding()
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                    }
                    Spacer()
                    HStack {
                        Button {
                            viewStore.send(.minusButtonTapped)
                        } label: {
                            Image(systemName: "minus")
                                .foregroundColor(.white)
                        }
                        .frame(width: 60, height: 60, alignment: .center)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .font(Font.system(size: 27))
                        .foregroundColor(Color.red)
                        Spacer()
                        Text("Scramble size: \(viewStore.currentScrambleLength)")
                            .font(.system(size: 17, weight: .semibold, design: .monospaced))
                            .foregroundColor(.black)
                        Spacer()
                        Button {
                            viewStore.send(.plusButtonTapped)
                        } label: {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                        }
                        .frame(width: 60, height: 60, alignment: .center)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .font(Font.system(size: 27))
                        .foregroundColor(Color.red)
                    }.padding(30)
                }
            }.onTapGesture {
                viewStore.send(.generateButtonTapped)
            }
        }
    }
}
```

After all of that just create view and display it:

```swift
let view = ScramblerView(
    store: ScramblerStore(
        initialState: ScramblerState(),
        reducer: scramblerReducer,
        environment: ScramblerEnvironment(
            scrambleService: ScrambleServiceImplementation()
        )
    )
)
```

In our projects we use [code generation templates](https://github.com/Incetro/verse-templates) to create all of these components, inculding `Composer`:

```swift
// MARK: - ScramblerComposer

/// `Scrambler` module composer
///
/// `ScramblerComposer` is responsible for making `Scrambler` module instances.
/// You can choose a specification from `Specification` which defines your module type.
final class ScramblerComposer {

    // MARK: - Properties

    /// Current composer instance
    private static let composer = ScramblerComposer()

    /// Dependency injection container
    private let container: Container

    // MARK: - Initializers

    /// Default initializer
    /// - Parameter container: Dependency injection container
    init(container: Container = AssembliesHolder.container) {
        self.container = container
    }
    
    // MARK: - Composition

    /// Create a new `ScramblerView` instance for the given specification
    /// - Parameter specification: target specification value
    /// - Returns: a new `ScramblerView` instance for the given specification
    static func view() -> ScramblerView {
        ScramblerView(store: store())
    }

    /// Create a new `ScramblerStore` instance for the given specification
    /// - Parameter specification: target specification value
    /// - Returns: a new `ScramblerStore` instance for the given specification
    static func store() -> ScramblerStore {
        ScramblerStore(
            initialState: ScramblerState(),
            reducer: scramblerReducer,
            environment: environment()
        )
    }

    /// Create a new `ScramblerEnvironment` instance for the given specification
    /// - Parameter specification: target specification value
    /// - Returns: a new `ScramblerEnvironment` instance for the given specification
    static func environment() -> ScramblerEnvironment {
        composer.container.resolve(ScramblerEnvironment.self).unwrap()
    }
}

// MARK: - Aliases

/// `Reducer` alias
typealias ScramblerReducer = Reducer<ScramblerState, ScramblerAction, ScramblerEnvironment>

/// `Store` alias
typealias ScramblerStore = Store<ScramblerState, ScramblerAction>
```

It means you can compose your modules just like this:

```swift
let view = ScramblerComposer.view()
```

It's very useful when you have large DI structure. Composer resolves all dependencies for environment and you can create modules on the fly without necessarily to inject dependencies manually. More information you can get from our examples: [VoiceMemos](https://github.com/Incetro/voice-memos), [Dews](https://github.com/Incetro/dews), [Weather](https://github.com/Incetro/weather), [Meter](https://github.com/Incetro/meter)

## Debugging

You can use a couple of tools for debugging your applications:

`reducer.debug()` empowers a reducer with debug-printing that describes every action the reducer receives and every mutation it makes to state. Let's see how it works with. the Scrambler example:

When we tap on the white area we get this:

```diff
received action:
  ScramblerAction.generateButtonTapped
  ScramblerState(
    scramble: nil,
    currentScrambleLength: 10,
−   isScrambleRequestInFlight: false
+   isScrambleRequestInFlight: true
  )

received action:
  ScramblerAction.scrambleService(
    Result<ScrambleServiceAction, Never>.success(
      ScrambleServiceAction.scramble(
        "U D\' L U L D F2 B2 R2 L"
      )
    )
  )
  ScramblerState(
−   scramble: nil,
+   scramble: "U D\' L U L D F2 B2 R2 L",
    currentScrambleLength: 10,
−   isScrambleRequestInFlight: true
+   isScrambleRequestInFlight: false
  )
```

And we can see this if we tap on the `+` button:

```diff
received action:
  ScramblerAction.plusButtonTapped
  ScramblerState(
    scramble: "U D\' L U L D F2 B2 R2 L",
−   currentScrambleLength: 10,
+   currentScrambleLength: 11,
    isScrambleRequestInFlight: false
  )

received action:
  ScramblerAction.generateButtonTapped
  ScramblerState(
    scramble: "U D\' L U L D F2 B2 R2 L",
    currentScrambleLength: 11,
−   isScrambleRequestInFlight: false
+   isScrambleRequestInFlight: true
  )

received action:
  ScramblerAction.scrambleService(
    Result<ScrambleServiceAction, Never>.success(
      ScrambleServiceAction.scramble(
        "R D2 B2 D\' L2 B2 U D\' B\' F\' R"
      )
    )
  )
  ScramblerState(
−   scramble: "U D\' L U L D F2 B2 R2 L",
+   scramble: "R D2 B2 D\' L2 B2 U D\' B\' F\' R",
    currentScrambleLength: 11,
−   isScrambleRequestInFlight: true
+   isScrambleRequestInFlight: false
  )
```

I think you understand what we wanted to say with this :) just use it for cool debugging your modules.

`reducer.signpost()` instruments a reducer with signposts so that you can gain insight into how long actions take to execute, and when effects are running.

## Requirements

VERSE depends on the Combine framework, so it requires minimum deployment targets of iOS 13, macOS 10.15, Mac Catalyst 13, tvOS 13, and watchOS 6.

## Installation

You can add VERSE to an Xcode project by adding it as a package dependency.

  1. From the **File** menu, select **Add Packages...**
  2. Enter "https://github.com/Incetro/verse" into the package repository URL text field
  3. Depending on how your project is structured:
      - If you have a single application target that needs access to the library, then add **VERSE** directly to your application.
      - If you want to use this library from multiple Xcode targets, or mixing Xcode targets and SPM targets, you must create a shared framework that depends on **VERSE** and then depend on that framework in all of your targets.

## Other architectures

VERSE is built on a foundation of ideas popularized by other frameworks:

* [The Elm Architecture (TEA)](https://guide.elm-lang.org/architecture/)
* [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)
* [Redux](https://github.com/fellipecaetano/Redux.swift)
* [RIBs](https://github.com/uber/RIBs)
* [Loop](https://github.com/ReactiveCocoa/Loop)
* [Fluxor](https://github.com/FluxorOrg/Fluxor)
* [ReSwift](https://github.com/ReSwift/ReSwift)
* [Workflow](https://github.com/square/workflow)
* [ReactorKit](https://github.com/ReactorKit/ReactorKit)
* [Mobius.swift](https://github.com/spotify/mobius.swift)
* [RxFeedback](https://github.com/NoTests/RxFeedback.swift)
* [PromisedArchitectureKit](https://github.com/RPallas92/PromisedArchitectureKit)

In some ways VERSE is a little more opinionated than the other libraries. For example, Redux is not prescriptive with how one executes side effects, but TCA requires all side effects to be modeled in the `Effect` type and returned from the reducer.

In other ways TCA is a little more lax than the other libraries. For example, Elm controls what kinds of effects can be created via the `Cmd` type, but TCA allows an escape hatch to any kind of effect since `Effect` conforms to the Combine `Publisher` protocol.

And then there are certain things that TCA prioritizes highly that are not points of focus for Redux, Elm, or most other libraries. For example, composition is very important aspect of TCA, which is the process of breaking down large features into smaller units that can be glued together. This is accomplished with the `pullback` and `combine` operators on reducers, and it aids in handling complex features as well as modularization for a better-isolated code base and improved compile times.

This library is released under the MIT license. See [LICENSE](LICENSE) for details.
Thanks [pointfree](https://github.com/pointfreeco/swift-composable-architecture) very much for their idea 🖤
