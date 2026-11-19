import PhotosUI
import SwiftUI

/// The cover on a shelved book's page. Tapping it lets the reader photograph the
/// book, choose a photo, or remove theirs.
struct CoverPhotoMenu: View {
    let book: ShelvedBook
    let title: String
    /// Open Library's cover, shown until the reader adds a photo and again once they remove it.
    var art: CoverArt?
    let width: CGFloat
    var onCover: ((Covers.Loaded?) -> Void)?

    @State private var takingPhoto = false
    @State private var choosingPhoto = false
    @State private var chosen: PhotosPickerItem?

    var body: some View {
        Menu {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take a photo", systemImage: "camera") { takingPhoto = true }
            }
            Button("Choose a photo", systemImage: "photo") { choosingPhoto = true }
            if book.coverPhoto != nil {
                Button("Remove photo", systemImage: "trash", role: .destructive) { book.setCover(nil) }
            }
        } label: {
            BookCover(title: title, photo: book.coverPhoto, art: art, width: width, onCover: onCover)
                .overlay(alignment: .bottomTrailing) {
                    if book.coverPhoto == nil {
                        Image(systemName: "camera.fill")
                            .font(.footnote)
                            .foregroundStyle(.loeOnAccent)
                            .padding(7)
                            .background(.loeAccent, in: .circle)
                            .padding(6)
                    }
                }
        }
        .accessibilityLabel(Text(book.coverPhoto == nil ? "Add a cover photo" : "Change the cover photo"))
        .photosPicker(isPresented: $choosingPhoto, selection: $chosen, matching: .images)
        .onChange(of: chosen) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await keep(image)
                }
                chosen = nil
            }
        }
        .fullScreenCover(isPresented: $takingPhoto) {
            CameraPicker { image in
                Task { await keep(image) }
            }
            .ignoresSafeArea()
        }
    }

    private func keep(_ image: UIImage) async {
        let photo = await Task.detached(priority: .userInitiated) { CoverPhoto(image) }.value
        if let photo { book.setCover(photo) }
    }
}

/// The system camera, for one photo.
private struct CameraPicker: UIViewControllerRepresentable {
    let onPhoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPhoto: onPhoto, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onPhoto: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onPhoto: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onPhoto = onPhoto
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onPhoto(image) }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
