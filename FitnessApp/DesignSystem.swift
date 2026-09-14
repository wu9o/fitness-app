import SwiftUI

extension Color {
    static let appPaper = Color(red: 0.98, green: 0.976, blue: 0.957)
    static let appInk = Color(red: 0.082, green: 0.125, blue: 0.169)
    static let appSecondary = Color(red: 0.40, green: 0.44, blue: 0.50)
    static let appCoral = Color(red: 1.0, green: 0.416, blue: 0.29)
    static let appBlue = Color(red: 0.29, green: 0.486, blue: 1.0)
    static let appMint = Color(red: 0.608, green: 0.89, blue: 0.80)
    static let appLavender = Color(red: 0.718, green: 0.647, blue: 1.0)
    static let appLemon = Color(red: 0.965, green: 0.847, blue: 0.416)
}

struct AppCard: ViewModifier {
    var fill: Color = .white

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    func appCard(fill: Color = .white) -> some View {
        modifier(AppCard(fill: fill))
    }
}

struct SectionTitle: View {
    let title: String
    let action: String?

    init(_ title: String, action: String? = nil) {
        self.title = title
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appInk)
            Spacer()
            if let action {
                Text(action)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appSecondary)
            }
        }
    }
}
