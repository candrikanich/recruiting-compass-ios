import Foundation
@testable import TheRecruitingCompass

final class MockCommunicationTemplatesService: CommunicationTemplatesServicing, @unchecked Sendable {
  // MARK: - Stubbed Data

  var mockTemplates: [CommunicationTemplate] = []
  var mockCreatedTemplate: CommunicationTemplate?
  var mockUpdatedTemplate: CommunicationTemplate?

  // MARK: - Error Flags

  var shouldThrowOnFetch = false
  var shouldThrowOnCreate = false
  var shouldThrowOnUpdate = false
  var shouldThrowOnDelete = false

  // MARK: - Call Counts

  var fetchTemplatesCallCount = 0
  var createTemplateCallCount = 0
  var updateTemplateCallCount = 0
  var deleteTemplateCallCount = 0

  // MARK: - Captured Arguments

  var lastCreateFormData: TemplateFormData?
  var lastUpdateId: String?
  var lastUpdateFormData: TemplateFormData?
  var lastDeleteId: String?

  // MARK: - CommunicationTemplatesServicing

  func fetchTemplates() async throws -> [CommunicationTemplate] {
    fetchTemplatesCallCount += 1
    if shouldThrowOnFetch {
      throw NSError(
        domain: "MockCommunicationTemplates",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Mock fetch error"]
      )
    }
    return mockTemplates
  }

  func createTemplate(formData: TemplateFormData) async throws -> CommunicationTemplate {
    createTemplateCallCount += 1
    lastCreateFormData = formData
    if shouldThrowOnCreate {
      throw NSError(
        domain: "MockCommunicationTemplates",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Mock create error"]
      )
    }
    return mockCreatedTemplate ?? makeTemplate(
      id: "new-template",
      name: formData.name,
      type: formData.type,
      body: formData.body
    )
  }

  func updateTemplate(id: String, formData: TemplateFormData) async throws -> CommunicationTemplate {
    updateTemplateCallCount += 1
    lastUpdateId = id
    lastUpdateFormData = formData
    if shouldThrowOnUpdate {
      throw NSError(
        domain: "MockCommunicationTemplates",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Mock update error"]
      )
    }
    return mockUpdatedTemplate ?? makeTemplate(
      id: id,
      name: formData.name,
      type: formData.type,
      body: formData.body
    )
  }

  func deleteTemplate(id: String) async throws {
    deleteTemplateCallCount += 1
    lastDeleteId = id
    if shouldThrowOnDelete {
      throw NSError(
        domain: "MockCommunicationTemplates",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "Mock delete error"]
      )
    }
  }

  // MARK: - Reset

  func reset() {
    mockTemplates = []
    mockCreatedTemplate = nil
    mockUpdatedTemplate = nil
    shouldThrowOnFetch = false
    shouldThrowOnCreate = false
    shouldThrowOnUpdate = false
    shouldThrowOnDelete = false
    fetchTemplatesCallCount = 0
    createTemplateCallCount = 0
    updateTemplateCallCount = 0
    deleteTemplateCallCount = 0
    lastCreateFormData = nil
    lastUpdateId = nil
    lastUpdateFormData = nil
    lastDeleteId = nil
  }

  // MARK: - Helper

  private func makeTemplate(
    id: String,
    name: String,
    type: TemplateType,
    body: String
  ) -> CommunicationTemplate {
    CommunicationTemplate(
      id: id,
      userId: "user-1",
      name: name,
      type: type,
      body: body,
      variables: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }
}
