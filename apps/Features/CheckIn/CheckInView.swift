import SwiftUI

struct CheckInView: View {
    @State private var stressLevel = 3.0
    @State private var energyLevel = 3.0
    @State private var caffeineServings = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Stress") {
                    Slider(value: $stressLevel, in: 1...5, step: 1)
                    Text("Current stress: \(Int(stressLevel))/5")
                }

                Section("Energy") {
                    Slider(value: $energyLevel, in: 1...5, step: 1)
                    Text("Current energy: \(Int(energyLevel))/5")
                }

                Section("Habits") {
                    Stepper("Caffeine servings: \(caffeineServings)", value: $caffeineServings, in: 0...8)
                }

                Button("Save Check-In") {
                    // Wire to persistence and sync in the next iteration.
                }
            }
            .navigationTitle("Daily Check-In")
        }
    }
}

#Preview {
    CheckInView()
}
