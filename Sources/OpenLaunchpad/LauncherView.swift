import SwiftUI
import AppKit
import LauncherCore
import UniformTypeIdentifiers

let launchpadDragType = UTType(exportedAs: "org.openlaunchpad.items", conformingTo: .data)

struct LauncherView: View {
    @ObservedObject var store: LibraryStore
    @FocusState private var searchFocused: Bool
    @ViewState private var dragOffset: CGFloat = 0
    @ViewState private var magnification: CGFloat = 1
    @ViewState private var dropTarget: String?
    @ViewState private var frames: [String: CGRect] = [:]
    @ViewState private var marquee: CGRect?
    @ViewState private var marqueeStart: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    private var classic: Bool { store.preferences.interfaceStyle == "Classic" }
    private var items: [LayoutItem] { store.displayedItems }
    private var paged: Bool { store.preferences.browse == .pages && store.query.isEmpty }
    private var renamePresented: Binding<Bool> { Binding(get: { store.renameID != nil }, set: { if !$0 { store.renameID = nil } }) }
    private var uninstallPresented: Binding<Bool> { Binding(get: { store.uninstallApp != nil }, set: { if !$0 { store.uninstallApp = nil } }) }
    private var messagePresented: Binding<Bool> { Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } }) }
    var body: some View {
        GeometryReader { geometry in surface(geometry: geometry) }
            .preferredColorScheme(store.preferences.appearance == "System" ? nil : store.preferences.appearance == "Light" ? .light : .dark)
            .sheet(isPresented: renamePresented) { renameSheet }
            .sheet(isPresented: uninstallPresented) { UninstallSheet(store: store) }
            .sheet(isPresented: Binding(get: { store.infoApp != nil }, set: { if !$0 { store.infoApp = nil } })) { AppInfoSheet(store: store) }
            .alert("OpenLaunchpad", isPresented: messagePresented) { if let url = store.updateURL { Button("View Release") { NSWorkspace.shared.open(url); store.updateURL = nil; store.message = nil } }; Button("OK") { store.message = nil } } message: { Text(store.message ?? "") }
            .onAppear { searchFocused = true }

            .onChange(of: store.folderID) { _, _ in searchFocused = true }
            .onReceive(NotificationCenter.default.publisher(for: .launcherDidShow)) { _ in searchFocused = true }
    }
    private func surface(geometry: GeometryProxy) -> some View {
        ZStack {
            background
            VStack(spacing: 0) {
                if classic {
                    if store.preferences.fullscreen { fullscreenToolbar.padding(.top, 46).padding(.bottom, 32) }
                    else { classicToolbar }
                }
                else {
                    header.padding(.horizontal, 38).padding(.top, 30)
                    searchBar.padding(.top, 26).padding(.bottom, 25)
                    if store.folderID != nil && store.query.isEmpty { folderHeader.padding(.bottom, 14) }
                }
                if store.preferences.showFavorites && !store.favorites.isEmpty && store.folderID == nil && store.query.isEmpty { favoritesBar }
                if store.scanning && items.isEmpty { ProgressView("Finding your applications…").frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if items.isEmpty { emptyState.frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if classic && store.preferences.fullscreen && store.folderID != nil && store.query.isEmpty { fullscreenFolder(geometry: geometry) }
                else {
                    Group {
                        if paged { pageDeck(geometry: geometry) }
                        else { grid(geometry: geometry) }
                    }.frame(maxWidth: classic && store.preferences.fullscreen ? 1760 : .infinity).clipped()
                }
                if classic { classicFooter.padding(.bottom, store.preferences.fullscreen ? 108 : 18).padding(.top, 6) }
                else { footer.padding(.horizontal, 38).padding(.bottom, 24).padding(.top, 16) }
            }
            .scaleEffect(reduceMotion ? 1 : magnification)
            .opacity(max(0.4, Double(magnification)))
            if store.editing && !store.selection.isEmpty { batchBar.frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 70) }
        }
        .clipShape(RoundedRectangle(cornerRadius: store.preferences.fullscreen ? 0 : classic ? 34 : 28))
        .overlay(RoundedRectangle(cornerRadius: store.preferences.fullscreen ? 0 : classic ? 34 : 28).stroke(.white.opacity(0.18), lineWidth: 1))
        .contextMenu { backgroundMenu }
        .simultaneousGesture(MagnificationGesture().onChanged { value in magnification = min(1.03, max(0.72, value)) }.onEnded { value in if value > 1.18 { store.escape() }; withAnimation { magnification = 1 } })
    }
    @ViewBuilder private var background: some View {
        ZStack {
            if classic && !store.preferences.wallpaper && !store.preferences.fullscreen {
                GlassBackground()
                Color.black.opacity(colorScheme == .light ? store.preferences.tint : 0.48 + store.preferences.tint * 0.4)
            } else {
            LinearGradient(colors: [Color(red: 0.08, green: 0.14, blue: 0.22), Color(red: 0.13, green: 0.24, blue: 0.29), Color(red: 0.08, green: 0.11, blue: 0.19)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if store.preferences.wallpaper || (classic && store.preferences.fullscreen) {
                WallpaperBackground(blur: reduceTransparency ? 0 : store.preferences.blur)
            }
            if !store.preferences.fullscreen || reduceTransparency { Rectangle().fill(.ultraThinMaterial).opacity(reduceTransparency ? 1 : 0.65) }
            Color.black.opacity(store.preferences.tint)
            if !store.preferences.wallpaper && !store.preferences.fullscreen {
                Circle().fill(Color.teal.opacity(0.12)).frame(width: 600).blur(radius: 100).offset(x: 270, y: -220)
                Circle().fill(Color.blue.opacity(0.12)).frame(width: 500).blur(radius: 100).offset(x: -400, y: 200)
            }
            }
        }.ignoresSafeArea().onTapGesture { store.escape() }
    }
    private var fullscreenToolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 17)).foregroundStyle(.secondary)
            TextField("Search Applications", text: $store.query).textFieldStyle(.plain).font(.system(size: 14))
                .focused($searchFocused).onSubmit { store.openSelection() }.accessibilityLabel("Search applications")
            if !store.query.isEmpty { Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) }
            Menu { launcherActions } label: { Image(systemName: "ellipsis.circle").font(.system(size: 17)) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Launcher actions")
        }.padding(.horizontal, 15).frame(width: 240, height: 38)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12)))
    }
    private func fullscreenFolder(geometry: GeometryProxy) -> some View {
        let rows = max(1, min(store.preferences.rows, Int(ceil(Double(items.count) / Double(store.preferences.columns)))))
        let height = min(geometry.size.height - 220, CGFloat(rows) * 190 + 60)
        return VStack(spacing: 24) {
            Spacer(minLength: 0)
            if let id = store.folderID {
                Button { store.rename(id) } label: { Text(store.item(id)?.name ?? "Folder").font(.system(size: 26, weight: .light)) }.buttonStyle(.plain)
            }
            grid(geometry: geometry, folderHeight: height).frame(height: height)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 42))
                .overlay(RoundedRectangle(cornerRadius: 42).stroke(.white.opacity(0.14)))
            Spacer(minLength: 0)
        }.frame(maxWidth: 1760).padding(.horizontal, 60)
    }
    private var classicToolbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                if let id = store.folderID, store.query.isEmpty {
                    Button { store.closeFolder() } label: { Image(systemName: "chevron.left").font(.system(size: 21, weight: .light)) }.buttonStyle(.plain).help("Back to all applications")
                    Spacer()
                    Button { store.rename(id) } label: { Text(store.item(id)?.name ?? "Folder").font(.system(size: 20, weight: .medium)) }.buttonStyle(.plain)
                    Spacer()
                    Color.clear.frame(width: 24)
                } else {
                    Image(systemName: "magnifyingglass").font(.system(size: 21, weight: .light)).foregroundStyle(.secondary)
                    TextField("Search Applications", text: $store.query).font(.system(size: 21, weight: .regular)).textFieldStyle(.plain).controlSize(.large).frame(height: 36).focused($searchFocused).onSubmit { store.openSelection() }.accessibilityLabel("Search applications")
                    if !store.query.isEmpty { Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain) }
                    Menu { launcherActions } label: { Image(systemName: "ellipsis.circle").font(.system(size: 22, weight: .light)).foregroundStyle(.secondary) }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Launcher actions")
                }
            }.padding(.horizontal, 24).frame(height: 64)
            .overlay(alignment: .top) { WindowDragHandle().frame(height: 12).overlay { Capsule().fill(.primary.opacity(0.15)).frame(width: 34, height: 3).allowsHitTesting(false) }.help("Drag to move launcher") }
            Divider().opacity(0.25)
        }
    }
    private var classicFooter: some View {
        HStack(spacing: 4) {
            if paged { ForEach(0..<store.pageCount, id: \.self) { index in Button { store.turnPage(index - store.page) } label: { Circle().fill(store.page == index ? Color.primary : Color.primary.opacity(0.25)).frame(width: 8, height: 8).padding(4) }.buttonStyle(.plain).accessibilityLabel("Page \(index + 1)") } }
            else { Text(store.query.isEmpty ? "\(store.visibleCount) applications" : "\(items.count) results").font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity).frame(height: 20)
            .background(WindowDragHandle())
    }
    @ViewBuilder private var launcherActions: some View { backgroundMenu }
    private var favoritesBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "star.fill").font(.caption).foregroundStyle(.secondary)
            ForEach(store.favorites.prefix(12)) { app in Button { store.launch(app) } label: { Image(nsImage: IconCache.shared.icon(app)).resizable().scaledToFit().frame(width: 28, height: 28) }.buttonStyle(.plain).help(app.displayName) }
        }.padding(.horizontal, 16).padding(.vertical, 8).glassEffect(.regular, in: .capsule).padding(.top, 12)
    }
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.3x3.fill").font(.system(size: 20, weight: .medium)).foregroundStyle(.mint)
                .frame(width: 42, height: 42).glassEffect(.regular, in: .rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text("OpenLaunchpad").font(.system(size: 18, weight: .semibold, design: .rounded))
                Text("A little space for everything.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Text("OPEN SOURCE").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.8).foregroundStyle(.mint.opacity(0.85))
                .padding(.horizontal, 12).padding(.vertical, 7).background(.mint.opacity(0.08), in: Capsule())
            Button { store.editing.toggle(); store.selection.removeAll() } label: { Image(systemName: store.editing ? "checkmark" : "square.and.pencil").frame(width: 28, height: 28) }
                .buttonStyle(.glass).help(store.editing ? "Finish organizing" : "Organize applications")
            Button { store.showSettings?() } label: { Image(systemName: "slider.horizontal.3").frame(width: 28, height: 28) }.buttonStyle(.glass).help("Settings (⌘,)")
            Button { store.dismiss?() } label: { Image(systemName: "xmark").frame(width: 28, height: 28) }.buttonStyle(.glass).help("Close (Esc)")
        }
    }
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search applications", text: $store.query).textFieldStyle(.plain).font(.system(size: 14))
                .focused($searchFocused).onSubmit { store.openSelection() }.accessibilityLabel("Search applications")
            if !store.query.isEmpty { Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain) }
            else { Text("⌘ K").font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary).padding(5).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 5)) }
        }.padding(.horizontal, 16).frame(width: 340, height: 45).glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
    private var folderHeader: some View {
        HStack {
            Button { store.closeFolder() } label: { Label("All applications", systemImage: "chevron.left") }.buttonStyle(.plain).foregroundStyle(.secondary)
            Spacer()
            if let id = store.folderID, let folder = store.item(id) { Button { store.rename(id) } label: { Text(folder.name ?? "Folder").font(.title2.weight(.semibold)) }.buttonStyle(.plain) }
            Spacer()
            Text("Folder").foregroundStyle(.tertiary)
        }.padding(.horizontal, 55)
    }
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: store.query.isEmpty ? "square.grid.3x3" : "magnifyingglass").font(.system(size: 42, weight: .ultraLight)).foregroundStyle(.secondary)
            Text(store.query.isEmpty ? "Your apps belong here" : "No applications found").font(.title3.weight(.medium))
            Text(store.query.isEmpty ? "Add an application folder in Settings to get started." : "Try an app name, initials, or a custom alias.").foregroundStyle(.secondary)
            if store.query.isEmpty { Button("Scan applications") { store.refresh() }.buttonStyle(.glass) }
        }
    }
    private func pageDeck(geometry: GeometryProxy) -> some View {
        GeometryReader { viewport in
            // Stable pages avoid allocating icon views and laying out a lazy grid
            // on the first animation frame. Only the deck's position changes.
            HStack(spacing: 0) {
                ForEach(0..<store.pageCount, id: \.self) { index in
                    grid(geometry: geometry, pageIndex: index)
                        .frame(width: viewport.size.width, height: viewport.size.height)
                        .allowsHitTesting(index == store.page)
                        .accessibilityHidden(index != store.page)
                }
            }
            .offset(x: -CGFloat(store.page) * viewport.size.width)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: store.page)
        }
    }
    private func grid(geometry: GeometryProxy, folderHeight: CGFloat? = nil, pageIndex: Int? = nil) -> some View {
        let columns = store.preferences.columns
        let availableHeight = folderHeight.map { $0 - 24 } ?? max(160, geometry.size.height - (classic ? store.preferences.fullscreen ? 260 : 115 : store.folderID == nil ? 235 : 280) - (store.preferences.showFavorites && !store.favorites.isEmpty && store.folderID == nil && store.query.isEmpty ? 50 : 0))
        let rowCount = folderHeight == nil ? store.preferences.rows : max(1, min(store.preferences.rows, Int(ceil(Double(items.count) / Double(columns)))))
        let contentWidth = classic && store.preferences.fullscreen ? min(1760, geometry.size.width - 120) : geometry.size.width
        let full = classic && store.preferences.fullscreen
        let cellWidth = (contentWidth - (full ? 0 : classic ? 80 : 150) - CGFloat(columns - 1) * (full ? 0 : 16)) / CGFloat(columns)
        let rowBudget = max(30, availableHeight / CGFloat(rowCount))
        let iconSize = min(classic ? store.preferences.fullscreen ? 128 : 72 : 88, max(18, min(cellWidth * 0.62, rowBudget * 0.60)))
        // Scrolling rows have a stable intrinsic height; screen height must not stretch them.
        let naturalRowHeight = iconSize + (store.preferences.fullscreen ? 72 : 48)
        let cellHeight = paged ? rowBudget : folderHeight != nil ? min(rowBudget, naturalRowHeight) : naturalRowHeight
        let gridPadding: CGFloat = paged ? 0 : 16
        let displayed = paged ? Array(items.dropFirst((pageIndex ?? store.page) * store.preferences.pageSize).prefix(store.preferences.pageSize)) : items
        return ScrollViewReader { reader in
            ScrollView(.vertical, showsIndicators: !paged && !store.preferences.fullscreen) {
                Group {
                    if paged {
                        Grid(horizontalSpacing: full ? 0 : 16, verticalSpacing: 0) {
                            ForEach(0..<max(1, Int(ceil(Double(displayed.count + (store.editing ? 1 : 0)) / Double(columns)))), id: \.self) { row in
                                GridRow {
                                    ForEach(0..<columns, id: \.self) { column in
                                        let index = row * columns + column
                                        if index < displayed.count {
                                            gridCell(displayed[index], iconSize: iconSize, height: cellHeight, collectFrames: pageIndex == nil || pageIndex == store.page).frame(maxWidth: .infinity)
                                        } else {
                                            Color.clear.frame(height: cellHeight).frame(maxWidth: .infinity)
                                                .onDrop(of: [launchpadDragType], isTargeted: nil) { handleDrop($0, target: nil, group: false) }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: full ? 0 : 16), count: columns), spacing: 0) {
                            ForEach(displayed) { item in gridCell(item, iconSize: iconSize, height: cellHeight) }
                            if store.editing { Color.clear.frame(height: cellHeight).contentShape(Rectangle()).onDrop(of: [launchpadDragType], isTargeted: nil) { providers in handleDrop(providers, target: nil, group: false) } }
                        }
                    }
                }.padding(.horizontal, full ? 0 : classic ? 32 : 52).padding(.vertical, gridPadding)
                if !paged && folderHeight == nil { Color.clear.frame(height: 55).contentShape(Rectangle()).onDrop(of: [launchpadDragType], isTargeted: nil) { handleDrop($0, target: nil, group: false) } }
            }
            .background { Color.clear.contentShape(Rectangle()).onTapGesture { store.escape() } }
            .scrollDisabled(paged)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85), value: store.state.items)
            .coordinateSpace(name: "grid")
            .onPreferenceChange(TileFramesKey.self) { if (pageIndex == nil || pageIndex == store.page) && frames != $0 { frames = $0 } }
            .overlay(alignment: .topLeading) { if let marquee { Rectangle().fill(.mint.opacity(0.12)).overlay(Rectangle().stroke(.mint.opacity(0.5))).frame(width: marquee.width, height: marquee.height).offset(x: marquee.minX, y: marquee.minY).allowsHitTesting(false) } }
            .simultaneousGesture(DragGesture(minimumDistance: 8, coordinateSpace: .named("grid")).onChanged { value in
                guard !store.dragging else { return }
                if NSEvent.modifierFlags.contains(.command) || store.editing {
                    if marqueeStart == nil { marqueeStart = value.startLocation }
                    let origin = marqueeStart!; let rect = CGRect(x: min(origin.x, value.location.x), y: min(origin.y, value.location.y), width: abs(origin.x - value.location.x), height: abs(origin.y - value.location.y))
                    marquee = rect; store.selection = Set(frames.filter { rect.intersects($0.value) }.map(\.key))
                } else if paged { dragOffset = value.translation.width }
            }.onEnded { value in
                if marquee != nil { marquee = nil; marqueeStart = nil }
                else if abs(value.translation.width) > 70 && dragOffset != 0 { store.turnPage(value.translation.width < 0 ? 1 : -1) }
                withAnimation(.easeOut(duration: 0.24)) { dragOffset = 0 }
            }, including: paged || store.editing || NSEvent.modifierFlags.contains(.command) ? .all : .subviews)
            .offset(x: reduceMotion ? 0 : dragOffset * 0.35 + store.pagingOffset)
            .onChange(of: store.selection) { _, selected in if !paged && !store.editing && marquee == nil, let id = selected.first { withAnimation { reader.scrollTo(id, anchor: .center) } } }
            .overlay(alignment: .leading) { if paged { edge(-1) } }
            .overlay(alignment: .trailing) { if paged { edge(1) } }
        }
    }
    @ViewBuilder private func gridCell(_ item: LayoutItem, iconSize: CGFloat, height: CGFloat, collectFrames: Bool = true) -> some View {
        if item.isSpacer {
            Color.clear.frame(height: height).onDrop(of: [launchpadDragType], isTargeted: nil) { handleDrop($0, target: item.id, group: false) }
        } else {
            tile(item, size: iconSize).frame(height: height).id(item.id)
                .background { if collectFrames && (store.editing || marqueeStart != nil) { GeometryReader { proxy in Color.clear.preference(key: TileFramesKey.self, value: [item.id: proxy.frame(in: .named("grid"))]) } } }
        }
    }
    private func tile(_ item: LayoutItem, size: CGFloat) -> some View {
        let selected = store.selection.contains(item.id)
        return VStack(spacing: 7) {
            ZStack(alignment: .topTrailing) {
                Group {
                    Group {
                        if item.isFolder { folderIcon(item, size: size) }
                        else if let app = store.app(item.apps[0]) {
                            Image(nsImage: IconCache.shared.icon(app)).resizable().interpolation(.high).scaledToFit()
                                .saturation(store.preferences.iconStyle == "Monochrome" ? 0 : 1)
                                .colorMultiply(store.preferences.iconStyle == "Tinted" ? .mint : .white)
                        }
                    }.frame(width: size, height: size)
                        .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
                        .modifier(IconHoverEffect(reduceMotion: reduceMotion))
                }
                .overlay { NativeIconInteraction(store: store, item: item) }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { store.activate(item) }
                if store.uninstallMode && !item.isFolder { Button { if let app = store.app(item.apps[0]) { store.previewUninstall(app) } } label: { Image(systemName: "minus.circle.fill").symbolRenderingMode(.palette).foregroundStyle(.white, .red).font(.system(size: 19)) }.buttonStyle(.plain).offset(x: 6, y: -4) }
                else if selected && (store.editing || store.selection.count > 1) { Image(systemName: "checkmark.circle.fill").symbolRenderingMode(.palette).foregroundStyle(.black, .mint).font(.system(size: 20)).offset(x: 6, y: -4).allowsHitTesting(false) }
            }
            if size >= 30 && (item.isFolder ? store.preferences.showFolderNames : store.preferences.showAppNames) {
                Text(store.title(item)).font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.tail).frame(maxWidth: .infinity).shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            }
        }
        .padding(.horizontal, 6).padding(.vertical, size < 40 ? 3 : 9)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(selected ? Color.mint.opacity(0.12) : .clear))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Color.mint.opacity(0.45) : .clear))
        .contentShape(Rectangle())
        .onDrop(of: [launchpadDragType], delegate: AppTileDropDelegate(store: store, item: item, iconSize: size, target: $dropTarget))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(dropTarget == item.id ? Color.accentColor : .clear, lineWidth: 2).allowsHitTesting(false))
        .contextMenu { itemMenu(item) }
        .accessibilityElement(children: .combine).accessibilityLabel(store.title(item)).accessibilityHint(item.isFolder ? "Open folder" : "Launch application")
    }
    private func folderIcon(_ item: LayoutItem, size: CGFloat) -> some View {
        let visibleSize = classic && store.preferences.fullscreen ? size * 0.8125 : size
        let miniature = max(4, (visibleSize - 26) / 3)
        return VStack(spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                ForEach(Array(item.apps.prefix(9)), id: \.self) { id in
                    if let app = store.app(id) { Image(nsImage: IconCache.shared.icon(app)).resizable().scaledToFit().frame(width: miniature, height: miniature) }
                }
            }
            Spacer(minLength: 0)
        }.padding(10).frame(width: visibleSize, height: visibleSize)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: visibleSize * 0.23))
            .overlay(RoundedRectangle(cornerRadius: visibleSize * 0.23).stroke(.white.opacity(0.1)))
    }
    private var footer: some View {
        HStack {
            HStack(spacing: 6) { Circle().fill(.mint).frame(width: 5, height: 5); Text(store.query.isEmpty ? "\(store.visibleCount) applications · \(store.folders.count) folders" : "\(items.count) results").font(.system(size: 11)).foregroundStyle(.secondary) }
            Spacer()
            if paged {
                HStack(spacing: 9) {
                    Button { store.turnPage(-1) } label: { Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold)) }.buttonStyle(.plain).disabled(store.page == 0)
                    ForEach(0..<store.pageCount, id: \.self) { index in Button { withAnimation { store.page = index } } label: { Capsule().fill(store.page == index ? Color.mint : Color.primary.opacity(0.25)).frame(width: store.page == index ? 20 : 6, height: 6).padding(.vertical, 8) }.buttonStyle(.plain).accessibilityLabel("Page \(index + 1)") }
                    Button { store.turnPage(1) } label: { Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)) }.buttonStyle(.plain).disabled(store.page == store.pageCount - 1)
                }.padding(.horizontal, 14).glassEffect(.regular, in: .capsule)
            }
            Spacer()
            Text(store.editing ? "⌘ click to select · drag to organize" : "← → navigate   ↵ open   esc close").font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
        }
    }
    private var batchBar: some View {
        HStack(spacing: 18) {
            Text("\(store.selection.count) selected").font(.callout.weight(.medium))
            Button("Create folder", systemImage: "folder.badge.plus") { store.groupSelection() }.disabled(store.folderID != nil || store.selection.count < 2)
            Menu("Move to folder") { ForEach(store.folders) { folder in Button(folder.name ?? "Folder") { store.moveToFolder(store.selection, folder: folder.id) } }; if store.folderID != nil { Button("All applications") { store.moveToFolder(store.selection, folder: nil) } } }
            Button("Hide", systemImage: "eye.slash") { store.hide(store.selection) }
            Button { store.selection.removeAll() } label: { Image(systemName: "xmark") }
        }.buttonStyle(.plain).padding(18).glassEffect(.regular, in: .capsule).shadow(radius: 20)
    }
    @ViewBuilder private func itemMenu(_ item: LayoutItem) -> some View {
        Button(item.isFolder ? "Open folder" : "Open") { store.activate(item) }
        Button("Rename…") { store.rename(item.id) }
        if item.isFolder {
            Button("Dissolve folder") { store.dissolve(item.id) }
            Menu("Move to page") {
                ForEach(0...store.pageCount, id: \.self) { page in Button(page == store.pageCount ? "New page" : "Page \(page + 1)") { store.moveToPage([item.id], page: page) } }
            }
        }
        else if let app = store.app(item.apps[0]) {
            Button(app.favorite == true ? "Unpin from favorites" : "Pin to favorites") { store.toggleFavorite(app.id) }
            Button("Add to Dock") { do { try DockIntegration.add(app) } catch { store.message = error.localizedDescription } }.disabled(DockIntegration.isPinned(app))
            Button("Get Info…") { store.infoApp = app }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)]) }
            Menu("Move to folder") {
                ForEach(store.folders.filter { $0.id != store.folderID }) { folder in Button(folder.name ?? "Folder") { store.moveToFolder([app.id], folder: folder.id) } }
                if store.folderID != nil { Button("All applications") { store.moveToFolder([app.id], folder: nil) } }
            }
            Menu("Move to page") {
                ForEach(0...store.pageCount, id: \.self) { page in Button(page == store.pageCount ? "New page" : "Page \(page + 1)") { store.moveToPage([item.id], page: page) } }
            }
            Divider(); Button("Clean uninstall…", role: .destructive) { store.previewUninstall(app) }.disabled(app.path.hasPrefix("/System/"))
        }
        Divider(); Button("Hide") { store.hide(store.selection.contains(item.id) ? store.selection : [item.id]) }
    }
    @ViewBuilder private var backgroundMenu: some View {
        Button("Settings…") { store.showSettings?() }.keyboardShortcut(",")
        Divider()
        Text("Sort By")
        Toggle("Custom", isOn: Binding(get: { store.preferences.sort == .manual }, set: { if $0 { store.updatePreferences { $0.sort = .manual } } }))
        ForEach(SortMode.allCases.filter { $0 != .manual }, id: \.self) { mode in
            Menu(mode == .recent ? "Date Last Opened" : mode.rawValue) {
                sortOption("Ascending", mode: mode, descending: false)
                sortOption("Descending", mode: mode, descending: true)
            }
        }
        Divider()
        Menu("Display Mode") {
            Toggle("Window", isOn: Binding(get: { !store.preferences.fullscreen }, set: { if $0 { store.updatePreferences { $0.fullscreen = false } } }))
            Toggle("Fullscreen", isOn: Binding(get: { store.preferences.fullscreen }, set: { if $0 { store.updatePreferences { $0.fullscreen = true } } }))
        }
        Menu("Browsing Style") {
            ForEach(BrowseMode.allCases, id: \.self) { mode in
                Toggle(mode == .scroll ? "Vertical Scroll" : "Horizontal Pages", isOn: Binding(get: { store.preferences.browse == mode }, set: { if $0 { store.updatePreferences { $0.browse = mode }; store.page = 0 } }))
            }
        }
        Divider()
        Button("Reorganize Layout…") { store.showReorganization?() }
        Menu("Quick Organization") {
            Button(store.editing ? "Done Organizing" : "Select & Organize Apps") { store.editing.toggle(); store.selection.removeAll() }
            Button("Apply Current Sort") { store.organize("Apply") }
            Divider()
            ForEach(["Fill empty slots", "Folders first", "Folders last", "Apple apps first", "Ungroup folders"], id: \.self) { action in Button(action) { store.organize(action) } }
        }
        Button("Undo Layout Change") { store.undo() }.disabled(!store.canUndo)
        Button("Redo Layout Change") { store.redo() }.disabled(!store.canRedo)
        Menu("Layout Profiles") {
            ForEach(store.state.profiles ?? []) { profile in Button(profile.name) { store.applyProfile(profile.id) } }
            Button("Manage Profiles…") { store.showSettings?() }
        }
        Divider()
        Button("Refresh Applications") { store.refresh() }
        Button("Check for Updates…") { store.checkForUpdates() }.disabled(store.checkingUpdates)
        Divider()
        Button("Restart") { store.restart?() }
        Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
    private func sortOption(_ title: String, mode: SortMode, descending: Bool) -> some View {
        Toggle(title, isOn: Binding(get: { store.preferences.sort == mode && store.preferences.descendingSort == descending }, set: { if $0 { store.updatePreferences { $0.sort = mode; $0.descendingSort = descending } } }))
    }
    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Give it a name").font(.title2.weight(.semibold))
            Text("The original application name stays unchanged.").foregroundStyle(.secondary)
            TextField("Name", text: $store.renameValue).textFieldStyle(.roundedBorder).onSubmit { store.commitRename() }
            HStack { Spacer(); Button("Cancel") { store.renameID = nil }.keyboardShortcut(.cancelAction); Button("Save") { store.commitRename() }.keyboardShortcut(.defaultAction).buttonStyle(.glassProminent) }
        }.padding(28).frame(width: 390)
    }
    private func handleDrop(_ providers: [NSItemProvider], target: String?, group: Bool) -> Bool {
        guard let provider = providers.first, store.query.isEmpty else { return false }
        provider.loadDataRepresentation(forTypeIdentifier: launchpadDragType.identifier) { data, _ in
            guard let data, let ids = try? JSONDecoder().decode([String].self, from: data) else { return }
            Task { @MainActor in store.drop(ids, target: target, group: group) }
        }
        return true
    }
    private func edge(_ direction: Int) -> some View { EdgeDropZone(store: store, direction: direction).frame(width: 22).frame(maxHeight: .infinity) }
}
@MainActor struct AppTileDropDelegate: DropDelegate {
    let store: LibraryStore
    let item: LayoutItem
    let iconSize: CGFloat
    @Binding var target: String?
    func validateDrop(info: DropInfo) -> Bool { store.query.isEmpty && info.hasItemsConforming(to: [launchpadDragType]) }
    func dropEntered(info: DropInfo) { target = item.id }
    func dropExited(info: DropInfo) { if target == item.id { target = nil } }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        target = nil
        guard let provider = info.itemProviders(for: [launchpadDragType]).first else { return false }
        // One target owns the entire tile; its center groups, its edges reorder.
        let grouping = info.location.y <= iconSize + 22 && info.location.y >= 6
        provider.loadDataRepresentation(forTypeIdentifier: launchpadDragType.identifier) { data, _ in
            guard let data, let ids = try? JSONDecoder().decode([String].self, from: data) else { return }
            Task { @MainActor in store.drop(ids, target: item.id, group: grouping) }
        }
        return true
    }
}
struct TileFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}
struct EdgeDropZone: View {
    @ObservedObject var store: LibraryStore
    let direction: Int
    @ViewState private var targeted = false
    @ViewState private var task: Task<Void, Never>?
    var body: some View {
        Rectangle().fill(targeted ? Color.mint.opacity(0.1) : .clear).contentShape(Rectangle())
            .onDrop(of: [launchpadDragType], isTargeted: $targeted) { providers in
                guard let provider = providers.first else { return false }
                provider.loadDataRepresentation(forTypeIdentifier: launchpadDragType.identifier) { data, _ in
                    guard let data, let ids = try? JSONDecoder().decode([String].self, from: data) else { return }
                    Task { @MainActor in store.moveToPage(ids, page: store.page) }
                }; return true
            }.onChange(of: targeted) { _, over in
                task?.cancel()
                if over { task = Task { try? await Task.sleep(for: .milliseconds(650)); guard !Task.isCancelled else { return }; if direction > 0 && store.page == store.pageCount - 1 && !store.extraPage { store.extraPage = true }; store.turnPage(direction) } }
            }
    }
}
extension Notification.Name { static let launcherDidShow = Notification.Name("OpenLaunchpad.didShow") }

private struct IconHoverEffect: ViewModifier {
    let reduceMotion: Bool
    @ViewState private var hovering = false
    func body(content: Content) -> some View {
        content.scaleEffect(hovering && !reduceMotion ? 1.04 : 1)
            .onHover { over in withAnimation(.easeOut(duration: 0.12)) { hovering = over } }
    }
}

struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {}
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            guard let window, !window.styleMask.contains(.fullScreen) else { return }
            window.performDrag(with: event)
        }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    }
}
