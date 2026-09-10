import SwiftUI

/// A quiet machined socket: detail stays subordinate to the colored game pieces.
struct EmptySocket: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(LinearGradient(colors: [Color(red: 0.64, green: 0.54, blue: 0.42), Color(red: 0.81, green: 0.73, blue: 0.61)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.brown.opacity(0.7), lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.22), lineWidth: 0.7).padding(2))
            .overlay {
                Canvas { context, size in
                    for x in [CGFloat(4), size.width - 4] {
                        for y in [CGFloat(4), size.height - 4] {
                            context.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(.brown.opacity(0.65)))
                            context.fill(Path(ellipseIn: CGRect(x: x - 0.5, y: y - 1, width: 1, height: 0.7)), with: .color(.white.opacity(0.65)))
                        }
                    }
                }
            }.accessibilityHidden(true)
    }
}
