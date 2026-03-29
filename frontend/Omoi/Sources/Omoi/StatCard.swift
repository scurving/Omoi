import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let subtitle: String?
    
    init(title: String, value: String, icon: String, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(.ultraThinMaterial) // The glass effect
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 1) // Frost border
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
