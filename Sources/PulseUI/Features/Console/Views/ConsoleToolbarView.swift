// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse
import CoreData
import Combine

#if os(iOS)
struct ConsoleToolbarView: View {
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        if #available(iOS 16.0, *) {
            ViewThatFits {
                horizontal
                vertical
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        } else {
            horizontal
        }
    }

    private var horizontal: some View {
        HStack(alignment: .bottom, spacing: 0) {
            contents(isVertical: false)
        }
        .buttonStyle(.plain)
    }

    // Fallback for larger dynamic font sizes.
    private var vertical: some View {
        VStack(alignment: .leading, spacing: 16) {
            contents(isVertical: true)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func contents(isVertical: Bool) -> some View {
        switch environment.initialMode {
        case .all:
            ConsoleModePicker(environment: environment)
        case .logs, .network:
            ConsoleToolbarTitle()
        }
        if !isVertical {
            Spacer()
        }
        HStack(spacing: 14) {
            ConsoleFiltersView(environment: environment)
        }.padding(.trailing, isVertical ? 0 : -2)
    }
}
#elseif os(macOS)
struct ConsoleToolbarView: View {
    let environment: ConsoleEnvironment

    @ObservedObject private var searchCriteriaViewModel: ConsoleSearchCriteriaViewModel

    init(environment: ConsoleEnvironment) {
        self.environment = environment
        self.searchCriteriaViewModel = environment.searchCriteriaViewModel
    }

    var body: some View {
        HStack {
            if searchCriteriaViewModel.options.focus != nil {
                makeFocusedView()
            } else {
                ConsoleModePicker(environment: environment)
            }
            Spacer()
            ConsoleFiltersView(environment: environment)
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .pickerStyle(.inline)
        }
        .padding(.horizontal, 10)
        .frame(height: 27, alignment: .center)
    }

    @ViewBuilder
    private func makeFocusedView() -> some View {
        Text("Focused Logs")
            .foregroundColor(.secondary)
            .font(.subheadline.weight(.medium))

        Button(action: { searchCriteriaViewModel.options.focus = nil }) {
            Image(systemName: "xmark")
        }
        .foregroundColor(.secondary)
        .buttonStyle(.plain)
        .help("Unfocus")
    }
}
#endif

struct ConsoleModePicker: View {
    private let environment: ConsoleEnvironment

    @ObservedObject private var logsCounter: ManagedObjectsCountObserver
    @ObservedObject private var tasksCounter: ManagedObjectsCountObserver

    @State private var mode: ConsoleMode = .all

    init(environment: ConsoleEnvironment) {
        self.environment = environment
        self.logsCounter = environment.logCountObserver
        self.tasksCounter = environment.taskCountObserver
    }

#if os(macOS)
    let spacing: CGFloat = 4
#else
    let spacing: CGFloat = 12
#endif

    var body: some View {
        HStack(spacing: spacing) {
            ConsoleModeButton(title: "All", isSelected: mode == .all) { mode = .all }
            ConsoleModeButton(title: "Logs", details: CountFormatter.string(from: logsCounter.count), isSelected: mode == .logs) { mode = .logs }
            ConsoleModeButton(title: "Network", details: CountFormatter.string(from: tasksCounter.count), isSelected: mode == .network) { mode = .network }
        }
        .onChange(of: mode) {
            environment.mode = $0
        }
    }
}

private struct ConsoleToolbarTitle: View {
    @State private var title: String = ""
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        Text(title)
            .foregroundColor(.secondary)
            .font(.subheadline.weight(.medium))
            .onReceive(titlePublisher) { title = $0 }
    }

    private var titlePublisher: some Publisher<String, Never> {
        let kind = environment.initialMode == .network ? "Requests" : "Logs"
        return environment.listViewModel.$entities.map { entities in
            "\(entities.count) \(kind)"
        }
    }
}

private struct ConsoleModeButton: View {
    let title: String
    var details: String?
    let isSelected: Bool
    let action: () -> Void

#if os(macOS)
    var body: some View {
        InlineTabBarItem(title: title, details: details, isSelected: isSelected, action: action)
    }
#else
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .foregroundColor(isSelected ? Color.blue : Color.secondary)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                if let details = details {
                    Text("(\(details))")
                        .foregroundColor(isSelected ? Color.blue.opacity(0.7) : Color.secondary.opacity(0.7))
                        .font(.subheadline)
                        .lineLimit(1)
                        .allowsTightening(true)
                }
            }
        }
        .buttonStyle(.plain)
    }
#endif
}

struct ConsoleFiltersView: View {
    let environment: ConsoleEnvironment

    @ObservedObject private var listViewModel: ConsoleListViewModel
    @ObservedObject private var searchCriteriaViewModel: ConsoleSearchCriteriaViewModel

    init(environment: ConsoleEnvironment) {
        self.environment = environment
        self.listViewModel = environment.listViewModel
        self.searchCriteriaViewModel = environment.searchCriteriaViewModel
    }

    var body: some View {
        if #available(iOS 15, *) {
            contents.dynamicTypeSize(...DynamicTypeSize.accessibility1)
        } else {
            contents
        }
    }

    @ViewBuilder
    private var contents: some View {
        if #available(iOS 15, *) {
#if os(iOS)
            sortByMenu.fixedSize()
#endif
            groupByMenu.fixedSize()
        }

        let criteria = searchCriteriaViewModel

#if os(macOS)
        Button(action: { criteria.options.isOnlyErrors.toggle() }) {
            Image(systemName: criteria.options.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .foregroundColor(criteria.options.isOnlyErrors ? .red : .primary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .help("Toggle Show Only Errors (⇧⌘E)")
#else
        Button(action: { criteria.options.isOnlyErrors.toggle() }) {
            Text(Image(systemName: criteria.options.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon"))
                .font(.body)
                .foregroundColor(criteria.options.isOnlyErrors ? .red : .blue)
        }
        .padding(.leading, 1)
#endif
    }

    @ViewBuilder
    private var sortByMenu: some View {
        Menu(content: {
            if environment.mode == .network {
                Picker("Sort By", selection: $listViewModel.options.taskSortBy) {
                    ForEach(ConsoleListOptions.TaskSortBy.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            } else {
                Picker("Sort By", selection: $listViewModel.options.messageSortBy) {
                    ForEach(ConsoleListOptions.MessageSortBy.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            }
            Picker("Ordering", selection: $listViewModel.options.order) {
                Text("Descending").tag(ConsoleListOptions.Ordering.descending)
                Text("Ascending").tag(ConsoleListOptions.Ordering.ascending)
            }
        }, label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.body)
                .foregroundColor(.blue)
        })
    }

    @ViewBuilder
    private var groupByMenu: some View {
        Menu(content: {
            if environment.mode == .network {
                Picker("Group By", selection: $listViewModel.options.taskGroupBy) {
                    Group {
                        Text("Ungrouped").tag(ConsoleListOptions.TaskGroupBy.noGrouping)
                        Divider()
                        Text("URL").tag(ConsoleListOptions.TaskGroupBy.url)
                        Text("Host").tag(ConsoleListOptions.TaskGroupBy.host)
                        Text("Method").tag(ConsoleListOptions.TaskGroupBy.method)
                    }
                    Group {
                        Divider()
                        Text("Content Type").tag(ConsoleListOptions.TaskGroupBy.responseContentType)
                        Text("Status Code").tag(ConsoleListOptions.TaskGroupBy.statusCode)
                        Text("Error Code").tag(ConsoleListOptions.TaskGroupBy.errorCode)
                        Divider()
                        Text("Task State").tag(ConsoleListOptions.TaskGroupBy.requestState)
                        Text("Task Type").tag(ConsoleListOptions.TaskGroupBy.taskType)
                        Divider()
                        Text("Session").tag(ConsoleListOptions.TaskGroupBy.session)
                    }
                }
            } else {
                Picker("Group By", selection: $listViewModel.options.messageGroupBy) {
                    Text("Ungrouped").tag(ConsoleListOptions.MessageGroupBy.noGrouping)
                    Divider()
                    ForEach(ConsoleListOptions.MessageGroupBy.allCases.filter { $0 != .noGrouping }, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            }
        }, label: {
            Image(systemName: "rectangle.3.group")
                .font(.body)
                .foregroundColor(.blue)
        })
    }
}

#endif
