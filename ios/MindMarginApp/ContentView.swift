import SwiftUI

struct ContentView: View {
    @StateObject private var appModel = MindMarginAppModel()

    var body: some View {
        AppRootView()
            .environmentObject(appModel)
            .task {
                await appModel.bootstrap()
            }
    }
}
