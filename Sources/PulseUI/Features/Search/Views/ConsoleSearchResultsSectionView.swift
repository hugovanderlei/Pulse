// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchResultView: View {
    let viewModel: ConsoleSearchResultViewModel
    var limit: Int = 4
    var isSeparatorNeeded = false

    var body: some View {
        ConsoleEntityCell(entity: viewModel.entity)
#if os(macOS)
            .tag(ConsoleSelectedItem.entity(viewModel.entity.objectID))
#endif
        let occurrences = Array(viewModel.occurrences).filter {
            // TODO: these should be displayed inline
            $0.scope != .message && $0.scope != .url
        }
        ForEach(occurrences.prefix(limit)) { item in
#if os(macOS)
            makeCell(for: item)
                .tag(ConsoleSelectedItem.occurrence(viewModel.entity.objectID, item))
#else
            NavigationLink(destination: ConsoleSearchResultView.makeDestination(for: item, entity: viewModel.entity)) {
                makeCell(for: item)
            }
#endif
        }
        if occurrences.count > limit {
            let total = occurrences.count > ConsoleSearchMatch.limit ? "\(ConsoleSearchMatch.limit)+" : "\(occurrences.count)"
#if os(macOS)
            Text("Total Results: \(total)")
                .font(ConsoleConstants.fontBody)
                .foregroundColor(.secondary)
                .padding(.top, 8)
#else
            NavigationLink(destination: ConsoleSearchResultDetailsView(viewModel: viewModel)) {
                Text("Total Results: ")
                    .font(ConsoleConstants.fontBody) +
                Text(total)
                    .font(ConsoleConstants.fontBody)
                    .foregroundColor(.secondary)
            }
#endif
        }
        if isSeparatorNeeded {
            PlainListGroupSeparator()
        }
    }

    @ViewBuilder
    private func makeCell(for occurrence: ConsoleSearchOccurrence) -> some View {
        let contents = VStack(alignment: .leading, spacing: 4) {
            Text(occurrence.scope.fullTitle + " (\(occurrence.line):\(occurrence.range.lowerBound + 1))")
                .font(ConsoleConstants.fontTitle)
                .foregroundColor(.secondary)
            Text(occurrence.preview)
                .lineLimit(3)
        }
        if #unavailable(iOS 16) {
            contents.padding(.vertical, 4)
        } else {
            contents
        }
    }

    @ViewBuilder
    static func makeDestination(for occurrence: ConsoleSearchOccurrence, entity: NSManagedObject) -> some View {
        _makeDestination(for: occurrence, entity: entity)
            .environment(\.textViewSearchContext, occurrence.searchContext)
    }

    @ViewBuilder
    private static func _makeDestination(for occurrence: ConsoleSearchOccurrence, entity: NSManagedObject) -> some View {
        switch LoggerEntity(entity) {
        case .message(let message):
            ConsoleMessageDetailsView(message: message)
        case .task(let task):
            _makeDestination(for: occurrence, task: task)
        }
    }

    @ViewBuilder
    private static func _makeDestination(for occurrence: ConsoleSearchOccurrence, task: NetworkTaskEntity) -> some View {
        switch occurrence.scope {
        case .url:
            NetworkDetailsView(title: "URL") {
                TextRenderer(options: .sharing).make {
                    $0.render(task, content: .requestComponents)
                }
            }
        case .originalRequestHeaders:
            makeHeadersDetails(title: "Request Headers", headers: task.originalRequest?.headers)
        case .currentRequestHeaders:
            makeHeadersDetails(title: "Request Headers", headers: task.currentRequest?.headers)
        case .requestBody:
            NetworkInspectorRequestBodyView(viewModel: .init(task: task))
        case .responseHeaders:
            makeHeadersDetails(title: "Response Headers", headers: task.response?.headers)
        case .responseBody:
            NetworkInspectorResponseBodyView(viewModel: .init(task: task))
        case .message, .metadata:
            EmptyView()
        }
    }

    private static func makeHeadersDetails(title: String, headers: [String: String]?) -> some View {
        NetworkDetailsView(title: title) {
            KeyValueSectionViewModel.makeHeaders(title: title, headers: headers)
        }
    }
}

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchResultDetailsView: View {
    let viewModel: ConsoleSearchResultViewModel

    var body: some View {
        List {
            ConsoleSearchResultView(viewModel: viewModel, limit: Int.max)
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .inlineNavigationTitle("Search Results")
    }
}

@available(iOS 15, tvOS 15, *)
struct PlainListGroupSeparator: View {
    var body: some View {
        Rectangle().foregroundColor(.clear) // DIY separator
            .frame(height: 12)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.separator.opacity(0.2))
#if os(iOS)
            .listRowSeparator(.hidden)
#endif
    }
}

@available(iOS 15, tvOS 15, *)
struct PlainListSectionHeader<Content: View>: View {
    var title: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        contents
            .padding(.top, 8)
            .listRowBackground(Color.separator.opacity(0.2))
#if os(iOS)
            .listRowSeparator(.hidden)
#endif
    }

    @ViewBuilder
    private var contents: some View {
        if let title = title {
            HStack(alignment: .bottom, spacing: 0) {
                Text(title)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
        } else {
            content()
        }
    }
}

@available(iOS 15, tvOS 15, *)
extension PlainListSectionHeader where Content == Text {
    init(title: String) {
        self.init(title: title, content: { Text(title) })
    }
}

@available(iOS 15, tvOS 15, *)
struct PlainListExpandableSectionHeader<Destination: View>: View {
    let title: String
    let count: Int
    @ViewBuilder let destination: () -> Destination
    var isSeeAllHidden = false

    var body: some View {
        PlainListSectionHeader {
            HStack(alignment: .bottom, spacing: 0) {
                Text(title)
                    .foregroundColor(.secondary)
                    .font(.subheadline.weight(.medium))
                +
                Text(" (\(count))")
                    .foregroundColor(.secondary.opacity(0.7))
                    .font(.subheadline.weight(.medium).monospacedDigit())
                if !isSeeAllHidden {
                    Spacer()
                    Text("See All")
                        .foregroundColor(.blue)
                        .font(.subheadline)
                        .background(NavigationLink("", destination: destination).opacity(0))
                }
            }
        }
    }
}

@available(iOS 15, tvOS 15, *)
struct PlainListSeeAllView: View {
    let count: Int

    var body: some View {
        (Text("See All").foregroundColor(.blue) +
         Text("  (\(count))"))
        .font(.subheadline)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 15, tvOS 15, *)
struct PlainListSectionHeaderSeparator: View {
    let title: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(title)
                .foregroundColor(.secondary)
                .font(.subheadline.weight(.medium))
            Spacer()
        }
    }
}

#endif
