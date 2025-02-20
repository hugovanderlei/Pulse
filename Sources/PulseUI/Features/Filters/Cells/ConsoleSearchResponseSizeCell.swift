// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse

struct ConsoleSearchResponseSizeCell: View {
    @Binding var selection: ConsoleSearchCriteria.ResponseSize

    var body: some View {
        HStack {
            Text("Size").lineLimit(1)
            Spacer()
            ConsoleSearchInlinePickerMenu(title: selection.unit.title, width: 50) {
                Picker("Unit", selection: $selection.unit) {
                    ForEach(ConsoleSearchCriteria.ResponseSize.MeasurementUnit.allCases) {
                        Text($0.title).tag($0)
                    }
                }
                .labelsHidden()
            }
            RangePicker(range: $selection.range)
        }
    }
}

#endif
