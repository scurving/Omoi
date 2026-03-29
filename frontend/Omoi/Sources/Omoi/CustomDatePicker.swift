import SwiftUI

struct CustomDatePicker: View {
    @Binding var selection: Date
    
    var body: some View {
        HStack(spacing: 8) {
            // Previous Day
            Button(action: {
                selection = Calendar.current.date(byAdding: .day, value: -1, to: selection) ?? selection
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(Color.omoiDarkGray)
                    .foregroundStyle(Color.omoiWhite)
                    .overlay(
                        Rectangle()
                            .stroke(Color.omoiGray, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            // Date Display
            HStack(spacing: 8) {
                Text(selection.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(OmoiFont.mono(size: 14))
                    .foregroundStyle(Color.omoiWhite)
                
                if !Calendar.current.isDateInToday(selection) {
                    Button(action: {
                        selection = Date()
                    }) {
                        Text("TODAY")
                            .font(OmoiFont.label(size: 10))
                            .foregroundStyle(Color.omoiBlack)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.omoiTeal)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(Color.omoiDarkGray)
            .overlay(
                Rectangle()
                    .stroke(Color.omoiGray, lineWidth: 1)
            )
            
            // Next Day
            Button(action: {
                selection = Calendar.current.date(byAdding: .day, value: 1, to: selection) ?? selection
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(Color.omoiDarkGray)
                    .foregroundStyle(Calendar.current.isDateInToday(selection) ? Color.omoiGray : Color.omoiWhite)
                    .overlay(
                        Rectangle()
                            .stroke(Color.omoiGray, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(Calendar.current.isDateInToday(selection))
        }
    }
}
