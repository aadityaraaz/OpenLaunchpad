import SwiftUI
// Use the stable property wrapper explicitly. The macOS 27 command-line SDK
// exposes an identically named @State macro without shipping SwiftUIMacros.
typealias ViewState<Value> = SwiftUI.State<Value>
