import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct CSVFilePicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    @Environment(\.presentationMode)
    private var presentationMode

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(
        context: Context
    ) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [
                .commaSeparatedText,
                .text,
                .data,
                .content
            ],
            asCopy: true
        )

        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.modalPresentationStyle = .formSheet

        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: Context
    ) {
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let parent: CSVFilePicker

        init(_ parent: CSVFilePicker) {
            self.parent = parent
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            guard let url = urls.first else {
                dismiss()
                return
            }

            parent.onPick(url)
            dismiss()
        }

        func documentPickerWasCancelled(
            _ controller: UIDocumentPickerViewController
        ) {
            dismiss()
        }

        private func dismiss() {
            DispatchQueue.main.async {
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct AudioFilePicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    @Environment(\.presentationMode)
    private var presentationMode

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(
        context: Context
    ) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.audio],
            asCopy: true
        )

        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.modalPresentationStyle = .formSheet

        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: Context
    ) {
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let parent: AudioFilePicker

        init(_ parent: AudioFilePicker) {
            self.parent = parent
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            guard let url = urls.first else {
                dismiss()
                return
            }

            parent.onPick(url)
            dismiss()
        }

        func documentPickerWasCancelled(
            _ controller: UIDocumentPickerViewController
        ) {
            dismiss()
        }

        private func dismiss() {
            DispatchQueue.main.async {
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct FolderPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    @Environment(\.presentationMode)
    private var presentationMode

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(
        context: Context
    ) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.folder],
            asCopy: false
        )

        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.modalPresentationStyle = .formSheet

        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: Context
    ) {
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let parent: FolderPicker

        init(_ parent: FolderPicker) {
            self.parent = parent
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            guard let url = urls.first else {
                dismiss()
                return
            }

            parent.onPick(url)
            dismiss()
        }

        func documentPickerWasCancelled(
            _ controller: UIDocumentPickerViewController
        ) {
            dismiss()
        }

        private func dismiss() {
            DispatchQueue.main.async {
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
