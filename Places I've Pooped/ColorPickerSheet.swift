struct ColorPickerSheet: View {
    @EnvironmentObject var groupsManager: GroupsManager
    @Binding var selectedColorHex: String
    @Binding var showSheet: Bool

    @State private var tempColor: Color = .blue
    @State private var showError = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ColorPicker("Pick a unique pin color", selection: $tempColor, supportsOpacity: false)
                    .padding()

                if showError {
                    Text("That color is already taken in this group.")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button("Confirm") {
                    let hex = tempColor.toHex()

                    if groupsManager.isColorTaken(hex) {
                        showError = true
                    } else {
                        selectedColorHex = hex
                        showSheet = false
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "#6B4F3B"))
                .foregroundColor(.white)
                .cornerRadius(10)

                Spacer()
            }
            .padding()
            .navigationTitle("Pick a Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showSheet = false
                    }
                }
            }
        }
    }
}
