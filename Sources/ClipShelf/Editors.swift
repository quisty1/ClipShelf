import SwiftUI
import ClipShelfCore

struct CollectionEditor: View {
    let app: AppController
    let collection: ClipCollection?
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(collection == nil ? "Новая коллекция" : "Переименовать коллекцию").font(.title2.bold())
            TextField("Название коллекции", text: $name).textFieldStyle(.roundedBorder).focused($focused)
            Text("Записи можно добавлять в несколько коллекций. Удаление коллекции не удаляет её содержимое.").font(.callout).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Сохранить") {
                    do {
                        if let collection { try app.repository.renameCollection(collection, to: name) }
                        else { try app.repository.createCollection(name) }
                        dismiss()
                    } catch { app.notify(error.localizedDescription) }
                }.keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(28).frame(width: 420).onAppear { name = collection?.name ?? ""; focused = true }
    }
}

struct SnippetEditor: View {
    let app: AppController
    let entry: ClipEntry?
    @State private var title = ""
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry?.isSnippet == true ? "Редактировать шаблон" : "Новый шаблон").font(.title2.bold())
            TextField("Название", text: $title).textFieldStyle(.roundedBorder)
            TextEditor(text: $text).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                .padding(8).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Текст шаблона")
            Text("Шаблоны сохраняются до ручного удаления. Текст вставляется без форматирования.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Сохранить") {
                    do {
                        if let entry, entry.isSnippet { try app.repository.edit(entry, title: title, text: text, snippet: true) }
                        else { try app.repository.saveSnippet(title: title, text: text) }
                        dismiss()
                    } catch { app.notify(error.localizedDescription) }
                }.keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.isEmpty)
            }
        }.padding(28).frame(width: 580, height: 440)
            .onAppear { title = entry?.title.isEmpty == false ? entry!.title : ""; text = entry?.text ?? "" }
    }
}
