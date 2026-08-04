import Foundation

struct TemplateFormData {
  var name: String = ""
  var type: TemplateType = .email
  var body: String = ""

  var isValid: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty
      && !body.trimmingCharacters(in: .whitespaces).isEmpty
  }

  init() {}

  init(from template: CommunicationTemplate) {
    self.name = template.name
    self.type = template.type
    self.body = template.body
  }
}
