import SwiftUI
import LauncherCore

struct ReorganizationView: View {
    @ObservedObject var store: LibraryStore
    let dismiss: () -> Void
    @ViewState private var sort: SortMode = .manual
    @ViewState private var descending = false
    @ViewState private var applePlacement = "Mixed"
    @ViewState private var folderPlacement = "Mixed"
    @ViewState private var ungroup = false
    @ViewState private var scope = "Current Page"
    @ViewState private var selected = Set<Int>()
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Reorganize Layout").font(.title2.weight(.semibold))
            Form {
                Picker("Sort By", selection: $sort) { ForEach(SortMode.allCases, id: \.self) { Text($0 == .manual ? "Current Order" : $0.rawValue).tag($0) } }
                Toggle("Descending order", isOn: $descending).disabled(sort == .manual)
                Picker("Apple App Placement", selection: $applePlacement) { Text("Mixed with Other Apps").tag("Mixed"); Text("Before Other Apps").tag("First"); Text("After Other Apps").tag("Last") }
                Toggle("Ungroup All Folders", isOn: $ungroup)
                Picker("Folder Placement", selection: $folderPlacement) { Text("Mixed with Apps").tag("Mixed"); Text("Before Apps").tag("First"); Text("After Apps").tag("Last") }.disabled(ungroup)
                Picker("Apply To", selection: $scope) { Text("Current Page (\(store.page + 1))").tag("Current Page"); Text("All Pages").tag("All Pages"); Text("Selected Pages").tag("Selected Pages") }
            }
            if scope == "Selected Pages" {
                ScrollView { LazyVGrid(columns: [GridItem(.adaptive(minimum: 85))]) {
                    ForEach(0..<store.pageCount, id: \.self) { page in
                        Toggle("Page \(page + 1)", isOn: Binding(get: { selected.contains(page) }, set: { if $0 { selected.insert(page) } else { selected.remove(page) } }))
                    }
                } }.frame(height: 70)
            }
            Text("Unselected pages keep their apps. Ungrouping can add slots and shift later pages. Undo restores your previous layout.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack { Spacer(); Button("Cancel", action: dismiss).keyboardShortcut(.cancelAction)
                Button("Reorganize") {
                    store.reorganize(sort: sort, descending: descending, applePlacement: applePlacement, folderPlacement: folderPlacement, ungroup: ungroup, pages: scope == "All Pages" ? nil : scope == "Current Page" ? [store.page] : selected)
                    dismiss()
                }.keyboardShortcut(.defaultAction).disabled(scope == "Selected Pages" && selected.isEmpty)
            }
        }.padding(26).frame(width: 420, height: 500).onAppear { selected = [store.page] }
    }
}
