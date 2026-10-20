import SwiftUI
import AppKit
import ImageIO
import ClipShelfCore

enum ShelfScope: Hashable { case history, favorites, snippets, collection(UUID) }
struct CollectionDraft: Identifiable { let id = UUID(); var collection: ClipCollection? }
struct SnippetDraft: Identifiable { let id = UUID(); var entry: ClipEntry? }

struct ShelfView: View {
    @Environment(\.appLanguage) private var language
    private var strings: Localizer { Localizer(language: language) }
    @Bindable var app: AppController
    @State private var query = ""
    @State private var scope: ShelfScope = .history
    @State private var kind: ClipKind?
    @State private var selectedID: UUID?
    @State private var collectionDraft: CollectionDraft?
    @State private var snippetDraft: SnippetDraft?
    @State private var clearConfirmation = false
    @FocusState private var searchFocused: Bool

    private var visible: [ClipEntry] {
        app.repository.search(query, kind: kind).filter { entry in
            switch scope {
            case .history: true
            case .favorites: entry.isFavorite
            case .snippets: entry.isSnippet
            case .collection(let id): entry.collectionIDs.contains(id)
            }
        }
    }
    private var selected: ClipEntry? { visible.first { $0.id == selectedID } }
    private var scopeTitle: String {
        switch scope {
        case .history: strings("History")
        case .favorites: strings("Favorites")
        case .snippets: strings("Snippets")
        case .collection(let id): app.repository.collections.first { $0.id == id }?.name ?? strings("Collection")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "square.on.square.fill").font(.title2).foregroundStyle(.tint)
                Text("ClipShelf").font(.system(size: 19, weight: .semibold, design: .rounded))
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(strings("Search history…"), text: $query)
                        .textFieldStyle(.plain).focused($searchFocused)
                        .accessibilityLabel(strings("Search history"))
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel(strings("Clear search"))
                    } else { Text("⌘F").font(.caption).foregroundStyle(.tertiary) }
                }
                .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 9))
                .frame(maxWidth: 440)
                Button { monitorPause() } label: { Image(systemName: app.preferences.paused ? "play.circle" : "pause.circle") }
                    .buttonStyle(.plain).font(.title3).help(app.preferences.paused ? strings("Resume Recording") : strings("Pause Recording"))
                Button { app.showSettings = true } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.plain).font(.title3).help(strings("Settings"))
            }
            .padding(.horizontal, 22).padding(.top, 30).padding(.bottom, 18)
            Divider()
            HStack(spacing: 0) {
                sidebar.frame(width: 185)
                Divider()
                history.frame(minWidth: 300, maxWidth: .infinity)
                Divider()
                preview.frame(width: 330)
            }
            Divider()
            footer
            if let notice = app.notice {
                HStack { Image(systemName: "info.circle"); Text(notice.text(strings: strings)).textSelection(.enabled); Spacer(); Button { app.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain) }
                    .font(.callout).padding(12).background(.tint.opacity(0.12))
            }
            if let error = app.monitor.errorMessage {
                HStack { Image(systemName: "exclamationmark.triangle"); Text(error.text(strings: strings)); Spacer(); Button(strings("Dismiss")) { app.monitor.errorMessage = nil } }
                    .font(.callout).padding(10).background(Color.orange.opacity(0.14))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(Color(red: 0.15, green: 0.50, blue: 0.44))
        .accentColor(Color(red: 0.15, green: 0.50, blue: 0.44))
        .background(KeyboardRouter(active: !app.showSettings && !app.showOnboarding && collectionDraft == nil && snippetDraft == nil && !clearConfirmation,
            move: moveSelection, submit: { copy in if let selected { app.use(selected, copyOnly: copy) } },
            escape: { app.hide() }, focus: { searchFocused = true }))
        .onAppear { resetSearch() }
        .onChange(of: app.presentationID) { resetSearch() }
        .onChange(of: visible.map(\.id)) {
            if !visible.contains(where: { $0.id == selectedID }) { selectedID = visible.first?.id }
        }
        .onChange(of: scope) { selectedID = visible.first?.id; searchFocused = true }
        .alert(strings("Clear History?"), isPresented: $clearConfirmation) {
            Button(strings("Cancel"), role: .cancel) {}
            Button(strings("Clear History"), role: .destructive) {
                app.perform { try app.repository.clear(includeProtected: false) }
            }
        } message: {
            Text(strings("Favorites, snippets, and items in collections will be kept. This cannot be undone."))
        }
        .sheet(isPresented: $app.showSettings) { SettingsView(app: app) }
        .sheet(isPresented: $app.showOnboarding) { OnboardingView(app: app) }
        .sheet(item: $collectionDraft) { draft in CollectionEditor(app: app, collection: draft.collection) }
        .sheet(item: $snippetDraft) { draft in SnippetEditor(app: app, entry: draft.entry) }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(strings("LIBRARY")).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(1).padding(.horizontal, 10).padding(.bottom, 8)
            scopeButton(strings("History"), symbol: "clock", value: .history, count: app.repository.entries.count)
            scopeButton(strings("Favorites"), symbol: "star", value: .favorites, count: app.repository.entries.filter(\.isFavorite).count)
            scopeButton(strings("Snippets"), symbol: "text.badge.plus", value: .snippets, count: app.repository.entries.filter(\.isSnippet).count)
            HStack {
                Text(strings("COLLECTIONS")).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                Spacer()
                Button { collectionDraft = CollectionDraft() } label: { Image(systemName: "plus") }.buttonStyle(.plain).help(strings("Create Collection"))
            }.padding(.horizontal, 10).padding(.top, 28).padding(.bottom, 6)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(app.repository.collections, id: \.id) { collection in
                        scopeButton(collection.name, symbol: "folder", value: .collection(collection.id), count: app.repository.entries.filter { $0.collectionIDs.contains(collection.id) }.count)
                            .contextMenu {
                                Button(strings("Rename…")) { collectionDraft = CollectionDraft(collection: collection) }
                                Button(strings("Delete Collection"), role: .destructive) {
                                    app.perform { try app.repository.deleteCollection(collection) }
                                    if scope == .collection(collection.id) { scope = .history }
                                }
                            }
                    }
                    if app.repository.collections.isEmpty { Text(strings("Organize what matters\nby topic")).font(.caption).foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .leading).padding(10) }
                }
            }
            Spacer(minLength: 8)
            Button { snippetDraft = SnippetDraft() } label: { Label(strings("New Snippet"), systemImage: "plus") }.buttonStyle(.bordered).frame(maxWidth: .infinity)
            Text(strings("Your clipboard, within reach.")).font(.system(size: 10)).foregroundStyle(.tertiary).padding(.horizontal, 10).padding(.top, 8)
        }.padding(.horizontal, 12).padding(.vertical, 24)
    }

    private func scopeButton(_ title: String, symbol: String, value: ShelfScope, count: Int) -> some View {
        Button { scope = value } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).frame(width: 16)
                Text(title).lineLimit(1)
                Spacer(minLength: 2)
                Text(count.formatted()).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }.font(.system(size: 12, weight: scope == value ? .semibold : .regular))
                .padding(.horizontal, 10).padding(.vertical, 10).contentShape(Rectangle())
                .background(scope == value ? Color.accentColor.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(scope == value ? Color.accentColor : Color.primary)
        }.buttonStyle(.plain).accessibilityAddTraits(scope == value ? .isSelected : [])
    }

    private var history: some View {
        VStack(spacing: 0) {
            HStack {
                Text(scopeTitle).font(.headline).lineLimit(1)
                Spacer()
                Text("\(visible.count)").font(.caption).foregroundStyle(.secondary)
                if scope == .history {
                    Button { clearConfirmation = true } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help(strings("Clear History…"))
                    .accessibilityLabel(strings("Clear History…"))
                    .disabled(!app.repository.entries.contains { !$0.isProtected })
                }
            }.padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 12)
            Picker(strings("Content Type"), selection: $kind) {
                Text(strings("All")).tag(ClipKind?.none)
                ForEach(ClipKind.allCases, id: \.self) { Text($0.label(language: language)).tag(Optional($0)) }
            }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 14).padding(.bottom, 14)
            if visible.isEmpty {
                VStack(spacing: 13) {
                    Image(systemName: query.isEmpty ? "square.on.square" : "magnifyingglass").font(.system(size: 36, weight: .light)).foregroundStyle(.tertiary)
                    Text(query.isEmpty ? strings("Your copies will appear here") : strings("No Results")).font(.headline)
                    Text(query.isEmpty ? strings("Copy text, a link, or an image.\nSave important items to a collection.") : strings("Try another search or content type."))
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 5) {
                            ForEach(visible, id: \.id) { entry in
                                ClipRow(entry: entry, imageURL: app.repository.imageURL(for: entry), selected: entry.id == selectedID)
                                    .contentShape(RoundedRectangle(cornerRadius: 10))
                                    .onTapGesture(count: 2) { app.use(entry) }
                                    .onTapGesture { selectedID = entry.id }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityAddTraits([.isButton])
                                    .accessibilityAction { selectedID = entry.id }
                                    .contextMenu { entryMenu(entry) }
                                    .id(entry.id)
                            }
                        }.padding(.horizontal, 10).padding(.bottom, 14)
                    }.onChange(of: selectedID) { if let selectedID { proxy.scrollTo(selectedID) } }
                }
            }
        }.background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }

    @ViewBuilder private var preview: some View {
        if let entry = selected {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(strings("PREVIEW")).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                    Spacer()
                    Button { app.perform { try app.repository.toggleFavorite(entry) } } label: { Image(systemName: entry.isFavorite ? "star.fill" : "star") }.buttonStyle(.plain).foregroundStyle(entry.isFavorite ? .orange : .secondary).help(strings("Favorites"))
                    Button { app.expand(entry) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.buttonStyle(.plain).help(strings("Expand Preview"))
                }
                Text(entry.displayTitle(language: language)).font(.system(size: 16, weight: .semibold)).lineLimit(3)
                PreviewContent(entry: entry, repository: app.repository, expanded: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 7) {
                    Label(entry.displaySource(language: language), systemImage: "app").lineLimit(1)
                    Label(entry.lastCopiedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(language.locale)), systemImage: "clock")
                    if entry.rtf != nil || entry.html != nil { Label(strings("Formatting preserved"), systemImage: "textformat") }
                    if entry.isProtected { Label(strings("Kept until you delete it"), systemImage: "pin") }
                }.font(.system(size: 11)).foregroundStyle(.secondary)
                HStack {
                    Menu { collectionMenu(entry) } label: { Label(strings("Add to Collection"), systemImage: "folder.badge.plus") }
                    Menu { entryMenu(entry) } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 28)
                }
                Button { app.use(entry) } label: { HStack { Text(strings("Paste")); Spacer(); Text("↵").foregroundStyle(.white.opacity(0.7)) }.padding(.vertical, 3) }
                    .buttonStyle(ShelfPrimaryButtonStyle())
            }.padding(22)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "viewfinder").font(.system(size: 35, weight: .ultraLight))
                Text(strings("Select an Item")).font(.callout)
                Text(strings("↑ ↓ to navigate\n↵ to paste")).font(.caption).multilineTextAlignment(.center)
            }.foregroundStyle(.tertiary).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Circle().fill(app.preferences.paused ? Color.orange : (app.monitor.canRead ? Color.accentColor : .orange)).frame(width: 5, height: 5)
            Text(app.monitor.status).lineLimit(1)
            Spacer()
            Text(strings("↑ ↓ select")).padding(.trailing, 10)
            Text(strings("⌘↵ copy")).padding(.trailing, 10)
            Text(strings("esc close"))
        }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.vertical, 12)
    }

    @ViewBuilder private func collectionMenu(_ entry: ClipEntry) -> some View {
        ForEach(app.repository.collections, id: \.id) { collection in
            Button { app.perform { try app.repository.toggleCollection(collection.id, for: entry) } } label: {
                if entry.collectionIDs.contains(collection.id) { Label(collection.name, systemImage: "checkmark") } else { Text(collection.name) }
            }
        }
        if app.repository.collections.isEmpty { Text(strings("Create a collection first")) }
        Divider()
        Button(strings("New Collection…")) { collectionDraft = CollectionDraft() }
    }
    @ViewBuilder private func entryMenu(_ entry: ClipEntry) -> some View {
        Button(strings("Paste")) { app.use(entry) }
        Button(strings("Copy")) { app.use(entry, copyOnly: true) }
        if entry.text != nil {
            Menu(strings("Transform and Paste")) {
                ForEach(TextTransform.allCases, id: \.self) { transform in Button(transform.label(language: language)) { app.use(entry, transform: transform) } }
            }
            Button(entry.isSnippet ? strings("Edit Snippet…") : strings("Save as Snippet…")) { snippetDraft = SnippetDraft(entry: entry) }
        }
        Button(entry.isFavorite ? strings("Remove from Favorites") : strings("Add to Favorites")) { app.perform { try app.repository.toggleFavorite(entry) } }
        Menu(strings("Collections")) { collectionMenu(entry) }
        Button(strings("Expand Preview")) { app.expand(entry) }
        Divider()
        Button(strings("Delete Item"), role: .destructive) { app.perform { try app.repository.delete(entry) } }
    }
    private func monitorPause() { app.monitor.ignoreCurrent(); app.preferences.paused.toggle() }
    private func resetSearch() { query = ""; selectedID = visible.first?.id; searchFocused = true }
    private func moveSelection(_ delta: Int) {
        guard !visible.isEmpty else { return }
        let index = selectedID.flatMap { id in visible.firstIndex { $0.id == id } } ?? 0
        selectedID = visible[min(max(index + delta, 0), visible.count - 1)].id
    }
}

struct ShelfPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ClipRow: View {
    @Environment(\.appLanguage) private var language
    private var strings: Localizer { Localizer(language: language) }
    let entry: ClipEntry
    let imageURL: URL?
    let selected: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(Color.accentColor.opacity(0.08))
                if entry.kind == .image, let imageURL {
                    Thumbnail(url: imageURL).clipShape(RoundedRectangle(cornerRadius: 7))
                } else { Image(systemName: entry.isSnippet ? "text.badge.plus" : entry.kind.symbol).font(.system(size: 18)).foregroundStyle(.tint) }
            }.frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(entry.displayTitle(language: language)).font(.system(size: 12, weight: .medium)).lineLimit(2)
                    Spacer(minLength: 3)
                    if entry.isFavorite { Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.orange) }
                }
                if let text = entry.text, !entry.title.isEmpty { Text(String(text.prefix(150))).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1) }
                HStack(spacing: 5) {
                    Text(entry.displaySource(language: language, fallbackToKind: true)).lineLimit(1)
                    Text("·")
                    Text(entry.lastCopiedAt, style: .relative).lineLimit(1)
                }.font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Color.accentColor.opacity(0.24) : .clear) }
    }
}

struct Thumbnail: View {
    let url: URL
    @State private var image: NSImage?
    var body: some View {
        Group { if let image { Image(nsImage: image).resizable().scaledToFit() } else { Image(systemName: "photo").foregroundStyle(.secondary) } }
            .task(id: url) { image = ImageThumbnail.load(url: url, maxPixel: 640) }
    }
}

enum ImageThumbnail {
    static func load(url: URL, maxPixel: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: maxPixel, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: .zero)
    }
}

struct PreviewContent: View {
    @Environment(\.appLanguage) private var language
    private var strings: Localizer { Localizer(language: language) }
    let entry: ClipEntry
    let repository: ClipRepository
    let expanded: Bool
    var body: some View {
        if entry.kind == .image, let url = repository.imageURL(for: entry) {
            Thumbnail(url: url).frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel(strings("Image Preview"))
        } else {
            ScrollView {
                Text(expanded ? (entry.text ?? "") : String((entry.text ?? "").prefix(12_000)))
                    .font(.system(size: expanded ? 15 : 12, design: .monospaced)).lineSpacing(5)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(14)
                if !expanded && (entry.text?.count ?? 0) > 12_000 { Text(strings("Showing an excerpt. Open the expanded preview for the full text.")).font(.caption).foregroundStyle(.secondary).padding(8) }
            }.background(.quaternary.opacity(0.30), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct ExpandedPreview: View {
    let entry: ClipEntry
    let repository: ClipRepository
    var body: some View { PreviewContent(entry: entry, repository: repository, expanded: true).padding(20).frame(minWidth: 400, minHeight: 300) }
}

struct KeyboardRouter: NSViewRepresentable {
    var active: Bool
    var move: (Int) -> Void
    var submit: (Bool) -> Void
    var escape: () -> Void
    var focus: () -> Void
    final class Coordinator {
        var configuration: KeyboardRouter
        weak var view: NSView?
        var token: Any?
        init(_ configuration: KeyboardRouter) { self.configuration = configuration }
        func install() {
            token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, configuration.active, let window = view?.window, event.window === window, window.isKeyWindow, window.attachedSheet == nil else { return event }
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
                if flags.isEmpty {
                    switch event.keyCode {
                    case 125: configuration.move(1); return nil
                    case 126: configuration.move(-1); return nil
                    case 36, 76: configuration.submit(false); return nil
                    case 53: configuration.escape(); return nil
                    default: break
                    }
                }
                if flags == .command {
                    if event.keyCode == 36 || event.keyCode == 76 { configuration.submit(true); return nil }
                    if event.charactersIgnoringModifiers?.lowercased() == "f" { configuration.focus(); return nil }
                }
                return event
            }
        }
        func stop() { if let token { NSEvent.removeMonitor(token); self.token = nil } }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSView {
        let view = NSView(); context.coordinator.view = view; context.coordinator.install(); return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { context.coordinator.configuration = self }
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.stop() }
}
