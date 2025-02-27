// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

struct ConsoleMessageCell: View {
    let viewModel: ConsoleMessageCellViewModel
    var isDisclosureNeeded = false

    var body: some View {
        let contents = VStack(alignment: .leading, spacing: 4) {
            if #available(iOS 15, tvOS 15, *) {
                header.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            } else {
                header
            }
            Text(viewModel.preprocessedText)
                .font(ConsoleConstants.fontBody)
                .foregroundColor(.textColor(for: viewModel.message.logLevel))
                .lineLimit(ConsoleSettings.shared.lineLimit)
        }
#if os(macOS)
        contents.padding(.vertical, 5)
#else
        if #unavailable(iOS 16) {
            contents.padding(.vertical, 4)
        } else {
            contents
        }
#endif
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text(viewModel.message.logLevel.name.uppercased())
                .lineLimit(1)
#if os(iOS)
                .font(ConsoleConstants.fontInfo.weight(.medium))
#else
                .font(ConsoleConstants.fontTitle.weight(.medium))
#endif
                .foregroundColor(titleColor)
            Spacer()
#if os(macOS) || os(iOS)
            PinView(message: viewModel.message)
#endif
            HStack(spacing: 3) {
                Text(viewModel.time)
                    .lineLimit(1)
                    .font(ConsoleConstants.fontInfo)
                    .foregroundColor(.secondary)
                    .backport.monospacedDigit()
                if isDisclosureNeeded {
                    ListDisclosureIndicator()
                }
            }
        }
    }

    var titleColor: Color {
        viewModel.message.logLevel >= .warning ? .textColor(for: viewModel.message.logLevel) : .secondary
    }
}

struct ListDisclosureIndicator: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .foregroundColor(.separator)
            .lineLimit(1)
            .font(ConsoleConstants.fontTitle)
            .foregroundColor(.secondary)
            .padding(.trailing, -12)
    }
}

#if DEBUG
struct ConsoleMessageCell_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleMessageCell(viewModel: .init(message: (try!  LoggerStore.mock.allMessages())[0]))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif

struct ConsoleConstants {
#if os(watchOS)
    static let fontTitle = Font.system(size: 14)
    static let fontInfo = Font.system(size: 14)
    static let fontBody = Font.system(size: 15)
#elseif os(macOS)
    static let fontTitle = Font.caption
    static let fontInfo = Font.caption
    static let fontBody = Font.body
#elseif os(iOS)
    static let fontTitle = Font.subheadline.monospacedDigit()
    static let fontInfo = Font.caption.monospacedDigit()
    static let fontBody = Font.callout
#else
    static let fontTitle = Font.caption
    static let fontInfo = Font.caption
    static let fontBody = Font.caption
#endif
}
