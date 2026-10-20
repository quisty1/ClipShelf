import SwiftUI
import ClipShelfCore

struct CollectionEditor: View {
    @Environment(\.appLanguage) private var language
    private var strings: Localizer { Localizer(language: language) }
    let app: AppController
    let collection: ClipCollection?
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(collection == nil ? strings("New Collection") : strings("Rename Collection")).font(.title2.bold())
            TextField(strings("Collection Name"), text: $name).textFieldStyle(.roundedBorder).focused($focused)
            Text(strings("Items can belong to multiple collections. Deleting a collection keeps its items.")).font(.callout).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(strings("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(strings("Save")) {
                    do {
                        if let collection { try app.repository.renameCollection(collection, to: name) }
                        else { try app.repository.createCollection(name) }
                        dismiss()
                    } catch { app.notify(error) }
                }.keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(28).frame(width: 420).onAppear { name = collection?.name ?? ""; focused = true }
    }
}

struct SnippetEditor: View {
    @Environment(\.appLanguage) private var language
    private var strings: Localizer { Localizer(language: language) }
    let app: AppController
    let entry: ClipEntry?
    @State private var title = ""
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry?.isSnippet == true ? strings("Edit Snippet") : strings("New Snippet")).font(.title2.bold())
            TextField(strings("Title"), text: $title).textFieldStyle(.roundedBorder)
            TextEditor(text: $text).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                .padding(8).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(strings("Snippet Text"))
            Text(strings("Snippets stay until you delete them. Text is pasted without formatting.")).font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(strings("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(strings("Save")) {
                    do {
                        if let entry, entry.isSnippet { try app.repository.edit(entry, title: title, text: text, snippet: true) }
                        else { try app.repository.saveSnippet(title: title, text: text) }
                        dismiss()
                    } catch { app.notify(error) }
                }.keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.isEmpty)
            }
        }.padding(28).frame(width: 580, height: 440)
            .onAppear { title = entry?.title.isEmpty == false ? entry!.title : ""; text = entry?.text ?? "" }
    }
}
