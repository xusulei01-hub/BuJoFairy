import SwiftUI

struct JournalReaderView: View {
    let journal: JournalEntry
    let onBack: () -> Void
    @State private var currentPage = 0
    @State private var viewMode: ViewMode = .magazine
    @State private var pages: [JournalPage] = []
    @State private var decodeError: String?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportedImage: NSImage?
    @State private var exportMessage: String?

    enum ViewMode: String, CaseIterable {
        case magazine = "翻页"
        case scroll = "长图"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("显示模式", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if let error = decodeError {
                ContentUnavailableView(
                    "无法显示手帐",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if pages.isEmpty {
                ContentUnavailableView(
                    "手帐内容为空",
                    systemImage: "book.pages",
                    description: Text("该手帐没有可显示的页面")
                )
            } else {
                switch viewMode {
                case .magazine:
                    VStack(spacing: 0) {
                        ScrollView {
                            JournalPageView(page: pages[currentPage], trip: journal.trip)
                                .frame(minHeight: 600)
                        }

                        HStack(spacing: 16) {
                            Button {
                                withAnimation { currentPage = max(0, currentPage - 1) }
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            .disabled(currentPage == 0)

                            Text("\(currentPage + 1) / \(pages.count)")
                                .font(.caption)
                                .monospacedDigit()

                            Button {
                                withAnimation { currentPage = min(pages.count - 1, currentPage + 1) }
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .disabled(currentPage == pages.count - 1)
                        }
                        .padding(.vertical, 8)
                    }

                case .scroll:
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                                JournalPageView(page: page, trip: journal.trip)
                                    .frame(minHeight: 600)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(journal.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("返回") { onBack() }
            }

            ToolbarItem {
                Menu {
                    Button {
                        exportLongImage(saveToFile: true)
                    } label: {
                        Label("保存到文件", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        exportLongImage(saveToFile: false)
                    } label: {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(isExporting || pages.isEmpty)
            }
        }
        .overlay {
            if isExporting {
                ZStack {
                    Color.black.opacity(0.4)
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在生成长图...")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .alert("导出", isPresented: .init(
            get: { exportMessage != nil },
            set: { if !$0 { exportMessage = nil } }
        )) {
            Button("确定") {}
        } message: {
            Text(exportMessage ?? "")
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = exportedImage {
                ShareServiceView(image: image)
            }
        }
        .task {
            decodeContent()
        }
    }

    private func decodeContent() {
        do {
            let content = try JSONDecoder().decode(JournalContent.self, from: journal.contentJSON)
            pages = content.pages
            decodeError = nil
        } catch {
            decodeError = "内容格式异常，无法显示手帐"
            pages = []
        }
    }

    private func exportLongImage(saveToFile shouldSave: Bool) {
        guard !pages.isEmpty else { return }
        isExporting = true

        Task {
            let image = await renderLongImage(pages: pages, trip: journal.trip)
            isExporting = false

            guard let image = image else {
                exportMessage = "生成图片失败"
                return
            }

            exportedImage = image

            if shouldSave {
                saveImageToFile(image)
            } else {
                showShareSheet = true
            }
        }
    }

    private func saveImageToFile(_ image: NSImage) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "\(journal.title).png"

        guard savePanel.runModal() == .OK, let url = savePanel.url else { return }

        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: url)
                exportMessage = "已保存到 \(url.path)"
            } catch {
                exportMessage = "保存失败: \(error.localizedDescription)"
            }
        } else {
            exportMessage = "图片编码失败"
        }
    }
}

@MainActor
private func renderLongImage(pages: [JournalPage], trip: Trip?) async -> NSImage? {
    let pageWidth: CGFloat = 780
    var pageImages: [NSImage] = []

    for page in pages {
        let renderer = ImageRenderer(
            content: JournalPageView(page: page, trip: trip)
                .frame(width: pageWidth)
        )
        renderer.proposedSize = ProposedViewSize(width: pageWidth, height: nil)
        if let image = renderer.nsImage {
            pageImages.append(image)
        }
    }

    guard !pageImages.isEmpty else { return nil }

    let totalHeight = pageImages.reduce(0) { $0 + $1.size.height }
    let size = NSSize(width: pageWidth, height: totalHeight)

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    bitmap.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    var y: CGFloat = 0
    for image in pageImages {
        image.draw(at: NSPoint(x: 0, y: y), from: .zero, operation: .sourceOver, fraction: 1.0)
        y += image.size.height
    }

    NSGraphicsContext.restoreGraphicsState()

    let result = NSImage(size: size)
    result.addRepresentation(bitmap)
    return result
}

struct ShareServiceView: View {
    let image: NSImage
    @Environment(\.dismiss) private var dismiss
    @State private var tempFileURL: URL?

    var body: some View {
        VStack(spacing: 16) {
            Text("分享手帐")
                .font(.headline)

            if let url = tempFileURL {
                HStack(spacing: 12) {
                    Button {
                        shareFile(url)
                    } label: {
                        Label("系统分享", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        copyImageToClipboard()
                    } label: {
                        Label("复制到剪贴板", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Text("准备分享中...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("关闭") {
                dismiss()
            }
        }
        .padding()
        .frame(width: 300, height: 180)
        .task {
            prepareTempFile()
        }
    }

    private func prepareTempFile() {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("journal-\(UUID().uuidString).png")
        do {
            try pngData.write(to: url)
            tempFileURL = url
        } catch {
            // Silently fail
        }
    }

    private func shareFile(_ url: URL) {
        let picker = NSSharingServicePicker(items: [url])
        if let window = NSApp.keyWindow, let view = window.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }

    private func copyImageToClipboard() {
        guard let tiffData = image.tiffRepresentation else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(tiffData, forType: .tiff)
    }
}
