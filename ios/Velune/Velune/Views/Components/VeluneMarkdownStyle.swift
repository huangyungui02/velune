import MarkdownUI
import SwiftUI

extension View {
    func veluneMarkdownBodyStyle() -> some View {
        self
            .markdownTextStyle {
                ForegroundColor(UITheme.primaryText)
            }
            .markdownBlockStyle(\.paragraph) { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.32))
                    .markdownMargin(top: .zero, bottom: .em(0.82))
            }
            .markdownBlockStyle(\.list) { configuration in
                configuration.label
                    .markdownMargin(top: .zero, bottom: .em(0.82))
            }
            .markdownBlockStyle(\.listItem) { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.32))
                    .markdownMargin(top: .em(0.82), bottom: .zero)
            }
            .fontDesign(.serif)
            .multilineTextAlignment(.leading)
    }
}
