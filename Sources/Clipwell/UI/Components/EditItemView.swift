// UI/Components/EditItemView.swift
// Clipwell v1.2 — Sheet for editing the text of a clipboard item in-place.

import SwiftUI

struct EditItemView: View {

    let item: ClipboardItem
    @Binding var isPresented: Bool

    @EnvironmentObject private var repository: ClipboardRepository

    @State private var editedText: String

    init(item: ClipboardItem, isPresented: Binding<Bool>) {
        self.item = item
        self._isPresented = isPresented
        self._editedText = State(initialValue: item.plainText ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack {
                Label("Edit Clipboard Item", systemImage: "pencil")
                    .font(.headline)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Editor
            TextEditor(text: $editedText)
                .font(.system(size: 12, design: .default))
                .frame(minHeight: 120, maxHeight: 300)
                .padding(6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                )

            // Character count
            HStack {
                Text("\(editedText.count) characters")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("Save") {
                    guard !editedText.isEmpty else { return }
                    repository.updateText(for: item.id, newText: editedText)
                    isPresented = false
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(editedText.isEmpty || editedText == item.plainText)
            }
        }
        .padding(16)
        .frame(width: 380)
    }
}
