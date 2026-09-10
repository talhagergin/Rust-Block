import SwiftUI

enum RustTheme {
    static let ink = Color(red: 0.10, green: 0.16, blue: 0.17), teal = Color(red: 0.04, green: 0.48, blue: 0.49)
    static let mint = Color(red: 0.24, green: 0.68, blue: 0.63), copper = Color(red: 0.76, green: 0.28, blue: 0.11)
    static let sand = Color(red: 0.96, green: 0.92, blue: 0.84), panel = Color.white.opacity(0.76)
}
struct MaterialBackground: View {
    var body: some View { ZStack { RustTheme.sand; Image("RustSurface").resizable().scaledToFill().opacity(0.56); LinearGradient(colors: [.white.opacity(0.35), .clear, RustTheme.mint.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing) }.ignoresSafeArea() }
}
struct IndustrialBackground: View {
    var body: some View {
        GeometryReader { geometry in ZStack {
            Color(red: 0.96, green: 0.89, blue: 0.73)
            Image("WorkshopBright").resizable().scaledToFill()
            LinearGradient(colors: [.white.opacity(0.12), .clear, Color.orange.opacity(0.08)], startPoint: .top, endPoint: .bottom)
        }.frame(width: geometry.size.width, height: geometry.size.height).clipped() }.ignoresSafeArea()
    }
}
struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(18).foregroundStyle(RustTheme.ink).background(LinearGradient(colors: [Color.white, RustTheme.sand], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22, style: .continuous)).brassBorder(radius: 22, width: 2).shadow(color: RustTheme.ink.opacity(0.2), radius: 10, y: 6) }
}
