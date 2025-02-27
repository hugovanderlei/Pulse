// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

/// Contains every dependency that the console views have.
///
/// - warning: It's marked with `ObservableObject` to make it possible to be used
/// with `@StateObject` and `@EnvironmentObject`, but it never changes.
final class ConsoleEnvironment: ObservableObject {
    let title: String
    let store: LoggerStore

    let listViewModel: ConsoleListViewModel

#if os(iOS) || os(macOS)
    @available(iOS 15, *)
    var searchViewModel: ConsoleSearchViewModel {
        _searchViewModel as! ConsoleSearchViewModel
    }
    private var _searchViewModel: AnyObject?

    let searchBarViewModel: ConsoleSearchBarViewModel
#endif

    let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel
    let index: LoggerStoreIndex

    let logCountObserver: ManagedObjectsCountObserver
    let taskCountObserver: ManagedObjectsCountObserver

    let router = ConsoleRouter()

    let initialMode: ConsoleMode

    var mode: ConsoleMode {
        didSet { prepare(for: mode) }
    }

    var bindingForNetworkMode: Binding<Bool> {
        Binding(get: {
            self.mode == .network
        }, set: {
            self.mode = $0 ? .network : .all
        })
    }

    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, mode: ConsoleMode = .all) {
        self.store = store
        switch mode {
        case .all: self.title = "Console"
        case .logs: self.title = "Logs"
        case .network: self.title = "Network"
        }
        self.initialMode = mode
        self.mode = mode

        func makeDefaultOptions() -> ConsolePredicateOptions {
            var options = ConsolePredicateOptions()
            options.criteria.shared.sessions.selection = [store.session.id]
            return options
        }

        self.index = LoggerStoreIndex(store: store)
        self.searchCriteriaViewModel = ConsoleSearchCriteriaViewModel(options: makeDefaultOptions(), index: index)
        self.listViewModel = ConsoleListViewModel(store: store, criteria: searchCriteriaViewModel)

#if os(iOS) || os(macOS)
        self.searchBarViewModel = ConsoleSearchBarViewModel()
        if #available(iOS 15, *) {
            self._searchViewModel = ConsoleSearchViewModel(list: listViewModel, index: index, searchBar: searchBarViewModel)
        }
#endif

        self.logCountObserver = ManagedObjectsCountObserver(
            entity: LoggerMessageEntity.self,
            context: store.viewContext,
            sortDescriptior: NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: false)
        )

        self.taskCountObserver = ManagedObjectsCountObserver(
            entity: NetworkTaskEntity.self,
            context: store.viewContext,
            sortDescriptior: NSSortDescriptor(keyPath: \NetworkTaskEntity.createdAt, ascending: false)
        )

        bind()

        if mode != .all {
            prepare(for: mode)
        }
    }

#if os(macOS)
    func focus(on entities: [NSManagedObject]) {
        searchCriteriaViewModel.options.focus = NSPredicate(format: "self IN %@", entities)
        listViewModel.options.messageGroupBy = .noGrouping
        listViewModel.options.taskGroupBy = .noGrouping
    }
#endif

    private func bind() {
        searchCriteriaViewModel.bind(listViewModel.$entities)
        searchCriteriaViewModel.$options.sink { [weak self] in
            self?.refreshCountObservers($0)
        }.store(in: &cancellables)
    }

    private func refreshCountObservers(_ options: ConsolePredicateOptions) {
        func makePredicate(for mode: ConsoleMode) -> NSPredicate? {
            ConsoleDataSource.makePredicate(mode: mode, options: options)
        }
        logCountObserver.setPredicate(makePredicate(for: .logs))
        taskCountObserver.setPredicate(makePredicate(for: .network))
    }

    private func prepare(for mode: ConsoleMode) {
        searchCriteriaViewModel.mode = mode
        listViewModel.mode = mode
    }

    func removeAllLogs() {
        store.removeAll()
        index.clear()


#if os(iOS)
        runHapticFeedback(.success)
        ToastView {
            HStack {
                Image(systemName: "trash")
                Text("All messages removed")
            }
        }.show()
#endif
    }
}

public enum ConsoleMode: String {
    /// Displays both messages and network tasks with the ability
    /// to switch between the two modes.
    case all
    /// Displays only regular messages.
    case logs
    /// Displays only network tasks.
    case network
}
