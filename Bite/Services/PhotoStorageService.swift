import UIKit
import ImageIO

final class PhotoStorageService {
    static let shared = PhotoStorageService()

    private let photosDirectory: URL

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        photosDirectory = documentsPath.appendingPathComponent("FoodPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
    }

    func savePhoto(_ image: UIImage) -> String? {
        let filename = UUID().uuidString + ".jpg"
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let fileURL = photosDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return filename
        } catch {
            return nil
        }
    }

    func loadPhoto(named filename: String) -> UIImage? {
        let fileURL = photosDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func loadThumbnail(named filename: String, maxSize: CGFloat = 200) -> UIImage? {
        let fileURL = photosDirectory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return loadPhoto(named: filename)
        }

        return UIImage(cgImage: thumbnail)
    }

    func deletePhoto(named filename: String) {
        let fileURL = photosDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
