import Foundation

struct DocumentCollection: Sendable {
  let documents: [Document]
  let currentIndex: Int

  var currentDocument: Document {
    documents[currentIndex]
  }

  var hasNext: Bool {
    currentIndex < documents.count - 1
  }

  var hasPrevious: Bool {
    currentIndex > 0
  }

  func nextDocument() -> Document? {
    hasNext ? documents[currentIndex + 1] : nil
  }

  func previousDocument() -> Document? {
    hasPrevious ? documents[currentIndex - 1] : nil
  }
}
