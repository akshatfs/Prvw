//
//  PreviewViewController.swift
//  PrvwExtension
//
//  Created by Akshat Shukla on 15/02/26.
//

import Cocoa
import Quartz
import UniformTypeIdentifiers

// MARK: - Column Identifiers

extension NSUserInterfaceItemIdentifier {
    static let nameColumn = NSUserInterfaceItemIdentifier("NameColumn")
    static let dateColumn = NSUserInterfaceItemIdentifier("DateColumn")
    static let sizeColumn = NSUserInterfaceItemIdentifier("SizeColumn")
}

// MARK: - Preview View Controller

class PreviewViewController: NSViewController, QLPreviewingController {
    
    // Archive / folder views
    private var outlineView: NSOutlineView!
    private var scrollView: NSScrollView!
    private var footerLabel: NSTextField!
    
    // Markdown views
    private var markdownScrollView: NSScrollView!
    private var markdownTextView: NSTextView!
    
    private var progressIndicator: NSProgressIndicator!
    private var errorLabel: NSTextField?
    private var rootItems: [PreviewItem] = []
    
    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
    
    private lazy var byteCountFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
    
    override var nibName: NSNib.Name? {
        return nil
    }
    
    override func loadView() {
        self.view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupOutlineView()
        setupMarkdownView()
        setupLoadingView()
    }
    
    // MARK: - Setup
    
    private func setupOutlineView() {
        // Create the outline view
        outlineView = NSOutlineView()
        outlineView.headerView = NSTableHeaderView()
        outlineView.usesAlternatingRowBackgroundColors = true
        outlineView.rowHeight = 22
        outlineView.indentationPerLevel = 18
        outlineView.autoresizesOutlineColumn = true
        outlineView.style = .automatic
        
        // Name column
        let nameColumn = NSTableColumn(identifier: .nameColumn)
        nameColumn.title = "Name"
        nameColumn.width = 300
        nameColumn.minWidth = 150
        nameColumn.resizingMask = .userResizingMask
        outlineView.addTableColumn(nameColumn)
        outlineView.outlineTableColumn = nameColumn
        
        // Date Modified column
        let dateColumn = NSTableColumn(identifier: .dateColumn)
        dateColumn.title = "Date Modified"
        dateColumn.width = 180
        dateColumn.minWidth = 100
        dateColumn.resizingMask = .userResizingMask
        outlineView.addTableColumn(dateColumn)
        
        // Size column
        let sizeColumn = NSTableColumn(identifier: .sizeColumn)
        sizeColumn.title = "Size"
        sizeColumn.width = 80
        sizeColumn.minWidth = 60
        sizeColumn.resizingMask = .userResizingMask
        outlineView.addTableColumn(sizeColumn)
        
        // Set delegates
        outlineView.dataSource = self
        outlineView.delegate = self
        
        // Wrap in scroll view
        scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Footer label
        footerLabel = NSTextField(labelWithString: "")
        footerLabel.isEditable = false
        footerLabel.isBordered = false
        footerLabel.drawsBackground = false
        footerLabel.alignment = .center
        footerLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        footerLabel.textColor = .secondaryLabelColor
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        view.addSubview(footerLabel)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            footerLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 4),
            footerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            footerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            footerLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
            footerLabel.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    private func setupMarkdownView() {
        // Text view
        markdownTextView = NSTextView()
        markdownTextView.isEditable = false
        markdownTextView.isSelectable = true
        markdownTextView.drawsBackground = true
        markdownTextView.backgroundColor = .textBackgroundColor
        markdownTextView.textContainerInset = NSSize(width: 20, height: 20)
        markdownTextView.autoresizingMask = [.width]
        markdownTextView.isVerticallyResizable = true
        markdownTextView.isHorizontallyResizable = false
        markdownTextView.textContainer?.widthTracksTextView = true
        markdownTextView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                               height: CGFloat.greatestFiniteMagnitude)
        // Scroll view
        markdownScrollView = NSScrollView()
        markdownScrollView.documentView = markdownTextView
        markdownScrollView.hasVerticalScroller = true
        markdownScrollView.hasHorizontalScroller = false
        markdownScrollView.autohidesScrollers = true
        markdownScrollView.borderType = .noBorder
        markdownScrollView.translatesAutoresizingMaskIntoConstraints = false
        markdownScrollView.isHidden = true
        
        view.addSubview(markdownScrollView)
        
        NSLayoutConstraint.activate([
            markdownScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            markdownScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            markdownScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            markdownScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    private func setupLoadingView() {
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .regular
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(progressIndicator)
        
        NSLayoutConstraint.activate([
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Error UI
    
    private func showError(_ message: String) {
        // Hide all content views so the user doesn't see blank content
        scrollView.isHidden = true
        markdownScrollView.isHidden = true
        
        // Reuse or create the error label
        if errorLabel == nil {
            let label = NSTextField(wrappingLabelWithString: "")
            label.isEditable = false
            label.isBordered = false
            label.drawsBackground = false
            label.alignment = .center
            label.font = NSFont.systemFont(ofSize: 13)
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            
            view.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ])
            
            errorLabel = label
        }
        
        errorLabel?.stringValue = message
        errorLabel?.isHidden = false
    }
    
    // MARK: - QLPreviewingController
    
    func preparePreviewOfFile(at url: URL) async throws {
        await MainActor.run {
            progressIndicator.startAnimation(nil)
            scrollView.isHidden = true
            markdownScrollView.isHidden = true
            footerLabel.isHidden = true
            errorLabel?.isHidden = true
        }
        
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let archiveType = detectArchiveType(url: url)
            
            if archiveType == .markdown {
                // Render markdown off the main thread, then display
                let attributed = try MarkdownRenderer.render(url: url)
                await MainActor.run {
                    self.progressIndicator.stopAnimation(nil)
                    self.markdownTextView.textStorage?.setAttributedString(attributed)
                    // Scroll to top
                    self.markdownTextView.scrollToBeginningOfDocument(nil)
                    self.markdownScrollView.isHidden = false
                    self.footerLabel.isHidden = true
                }
            } else {
                let items: [PreviewItem]
                switch archiveType {
                case .zip:
                    let entries = try ZipParser.parseEntries(from: url)
                    items = ArchiveTreeBuilder.buildTree(from: entries)
                case .tar:
                    let entries = try TarParser.parseEntries(from: url)
                    items = ArchiveTreeBuilder.buildTree(from: entries)
                case .gzipTar:
                    let entries = try GzipDecompressor.decompressAndParseTar(from: url)
                    items = ArchiveTreeBuilder.buildTree(from: entries)
                case .gzip:
                    let entries = try GzipDecompressor.parseStandaloneGzip(from: url)
                    items = ArchiveTreeBuilder.buildTree(from: entries)
                case .rar:
                    let entries = try RarParser.parseEntries(from: url)
                    items = ArchiveTreeBuilder.buildTree(from: entries)
                case .bz2Tar:
                    let entries = try Bz2Parser.decompressAndParseTar(from: url)
                    items = ArchiveTreeBuilder.buildTree(from: entries)
                case .bz2:
                    let entries = try Bz2Parser.parseStandaloneBz2(from: url)
                    items = ArchiveTreeBuilder.buildTree(from: entries)
                case .folder:
                    items = FileItem.loadChildren(of: url)
                case .markdown:
                    items = [] // unreachable
                }
                
                await MainActor.run {
                    self.progressIndicator.stopAnimation(nil)
                    self.rootItems = items
                    self.scrollView.isHidden = false
                    self.outlineView.reloadData()
                    self.updateFooter(with: items)
                }
            }
        } catch {
            await MainActor.run {
                self.progressIndicator.stopAnimation(nil)
                self.footerLabel.isHidden = true
                self.showError("Unable to preview this file: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Archive Type Detection
    
    private enum ArchiveType {
        case zip, tar, gzipTar, gzip, rar, bz2, bz2Tar, folder, markdown
    }
    
    private func detectArchiveType(url: URL) -> ArchiveType {
        // Check compound extensions first so ".tar.gz" isn't mismatched on "gz" alone
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".tar.gz") {
            return .gzipTar
        }
        if name.hasSuffix(".tar.bz2") || name.hasSuffix(".tbz") || name.hasSuffix(".tbz2") {
            return .bz2Tar
        }
        
        // Then check single extensions
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "md", "markdown":
            return .markdown
        case "zip":
            return .zip
        case "tar":
            return .tar
        case "tgz":
            return .gzipTar
        case "gz":
            return .gzip
        case "rar":
            return .rar
        case "bz2":
            return .bz2
        default:
            break
        }
        
        // Fall back to UTType
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            if let mdType = UTType("net.daringfireball.markdown"), type.conforms(to: mdType) { return .markdown }
            if type.conforms(to: UTType.zip) { return .zip }
            if type.conforms(to: UTType.gzip) { return .gzipTar }
            if let bz2Type = UTType(filenameExtension: "bz2"), type.conforms(to: bz2Type) { return .bz2 }
        }
        
        return .folder
    }
    
    // MARK: - Statistics
    
    private struct Statistics {
        var fileCount = 0
        var folderCount = 0
        var totalSize: Int64 = 0
        
        var summary: String {
            let files = fileCount == 1 ? "1 file" : "\(fileCount) files"
            let folders = folderCount == 1 ? "1 folder" : "\(folderCount) folders"
            return "\(files), \(folders)"
        }
    }
    
    private func updateFooter(with items: [PreviewItem]) {
        var stats = Statistics()
        
        func calculate(_ items: [PreviewItem]) {
            for item in items {
                if item.isDirectory {
                    stats.folderCount += 1
                    if let children = item.children {
                        calculate(children)
                    }
                } else {
                    stats.fileCount += 1
                    stats.totalSize += item.fileSize ?? 0
                }
            }
        }
        
        calculate(items)
        
        let sizeString = formatFileSize(stats.totalSize)
        footerLabel.stringValue = "\(stats.summary) • \(sizeString)"
        footerLabel.isHidden = false
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        return byteCountFormatter.string(fromByteCount: bytes)
    }
}

// MARK: - NSOutlineViewDataSource

extension PreviewViewController: NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return rootItems.count
        }
        guard let previewItem = item as? PreviewItem else { return 0 }
        return previewItem.children?.count ?? 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return rootItems[index]
        }
        guard let previewItem = item as? PreviewItem else { return NSObject() }
        return previewItem.children?[index] ?? NSObject()
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let previewItem = item as? PreviewItem else { return false }
        return previewItem.isDirectory && (previewItem.children?.isEmpty == false)
    }
}

// MARK: - NSOutlineViewDelegate

extension PreviewViewController: NSOutlineViewDelegate {
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let previewItem = item as? PreviewItem,
              let columnID = tableColumn?.identifier else {
            return nil
        }
        
        switch columnID {
        case .nameColumn:
            return makeNameCell(for: previewItem, in: outlineView)
        case .dateColumn:
            return makeDateCell(for: previewItem, in: outlineView)
        case .sizeColumn:
            return makeSizeCell(for: previewItem, in: outlineView)
        default:
            return nil
        }
    }
    
    // MARK: - Cell Factories
    
    private func makeNameCell(for item: PreviewItem, in outlineView: NSOutlineView) -> NSTableCellView {
        let cellID = NSUserInterfaceItemIdentifier("NameCell")
        let cell: NSTableCellView
        
        if let reused = outlineView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellID
            
            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.font = NSFont.systemFont(ofSize: 13)
            textField.lineBreakMode = .byTruncatingTail
            
            cell.addSubview(imageView)
            cell.addSubview(textField)
            cell.imageView = imageView
            cell.textField = textField
            
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        
        cell.imageView?.image = item.icon
        cell.textField?.stringValue = item.name
        
        return cell
    }
    
    private func makeDateCell(for item: PreviewItem, in outlineView: NSOutlineView) -> NSTableCellView {
        let cellID = NSUserInterfaceItemIdentifier("DateCell")
        let cell: NSTableCellView
        
        if let reused = outlineView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellID
            
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.font = NSFont.systemFont(ofSize: 12)
            textField.textColor = .secondaryLabelColor
            textField.lineBreakMode = .byTruncatingTail
            
            cell.addSubview(textField)
            cell.textField = textField
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        
        if let date = item.dateModified {
            cell.textField?.stringValue = dateFormatter.string(from: date)
        } else {
            cell.textField?.stringValue = "--"
        }
        
        return cell
    }
    
    private func makeSizeCell(for item: PreviewItem, in outlineView: NSOutlineView) -> NSTableCellView {
        let cellID = NSUserInterfaceItemIdentifier("SizeCell")
        let cell: NSTableCellView
        
        if let reused = outlineView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellID
            
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.font = NSFont.systemFont(ofSize: 12)
            textField.textColor = .secondaryLabelColor
            textField.lineBreakMode = .byTruncatingTail
            textField.alignment = .right
            
            cell.addSubview(textField)
            cell.textField = textField
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        
        if item.isDirectory {
            let count = item.children?.count ?? 0
            cell.textField?.stringValue = count == 1 ? "1 item" : "\(count) items"
        } else if let size = item.fileSize {
            cell.textField?.stringValue = formatFileSize(size)
        } else {
            cell.textField?.stringValue = "--"
        }
        
        return cell
    }
}
