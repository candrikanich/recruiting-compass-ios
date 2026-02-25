import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "CommunicationTemplatesViewModel"
)

@Observable
@MainActor
final class CommunicationTemplatesViewModel {

  enum Tab: String, CaseIterable {
    case list
    case create
  }

  var templates: [CommunicationTemplate] = []
  var isLoading = false
  var isSaving = false
  var errorMessage: String?
  var activeTab: Tab = .list
  var filterType: TemplateType?
  var editingTemplate: CommunicationTemplate?
  var formData = TemplateFormData()
  var showDeleteConfirmation = false
  var templateToDeleteId: String?

  private let service: any CommunicationTemplatesServicing

  var filteredTemplates: [CommunicationTemplate] {
    guard let filterType else { return templates }
    return templates.filter { $0.type == filterType }
  }

  var typeCounts: [TemplateType?: Int] {
    var counts: [TemplateType?: Int] = [nil: templates.count]
    for type in TemplateType.allCases {
      counts[type] = templates.filter { $0.type == type }.count
    }
    return counts
  }

  init(service: (any CommunicationTemplatesServicing)? = nil) {
    self.service = service ?? CommunicationTemplatesServiceImpl()
  }

  func loadTemplates() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      templates = try await service.fetchTemplates()
      logger.info("Loaded \(self.templates.count) templates")
    } catch {
      logger.error("Failed to load templates: \(error.localizedDescription)")
      errorMessage = "Failed to load templates. Please try again."
    }
  }

  func saveTemplate() async {
    guard formData.isValid else { return }

    errorMessage = nil
    isSaving = true
    defer { isSaving = false }

    do {
      if let editing = editingTemplate {
        let updated = try await service.updateTemplate(id: editing.id, formData: formData)
        if let index = templates.firstIndex(where: { $0.id == editing.id }) {
          templates[index] = updated
        }
        logger.info("Updated template: \(editing.id)")
      } else {
        let created = try await service.createTemplate(formData: formData)
        templates.insert(created, at: 0)
        logger.info("Created template: \(created.id)")
      }
      resetEditor()
      activeTab = .list
    } catch {
      logger.error("Failed to save template: \(error.localizedDescription)")
      errorMessage = "Failed to save template. Please try again."
    }
  }

  func confirmDelete(id: String) {
    templateToDeleteId = id
    showDeleteConfirmation = true
  }

  func executeDelete() async {
    guard let id = templateToDeleteId else { return }

    do {
      try await service.deleteTemplate(id: id)
      templates.removeAll { $0.id == id }
      resetEditor()
      activeTab = .list
      logger.info("Deleted template: \(id)")
    } catch {
      logger.error("Failed to delete template: \(error.localizedDescription)")
      errorMessage = "Failed to delete template. Please try again."
    }

    templateToDeleteId = nil
    showDeleteConfirmation = false
  }

  func startEditing(template: CommunicationTemplate) {
    editingTemplate = template
    formData = TemplateFormData(from: template)
    activeTab = .create
  }

  func cancelEdit() {
    resetEditor()
    activeTab = .list
  }

  func switchToCreateTab() {
    resetEditor()
    activeTab = .create
  }

  func selectFilter(_ type: TemplateType?) {
    filterType = type
  }

  private func resetEditor() {
    editingTemplate = nil
    formData = TemplateFormData()
  }
}
