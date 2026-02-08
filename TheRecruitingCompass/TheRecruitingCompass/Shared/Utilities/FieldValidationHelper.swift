import Foundation

struct FieldValidationInput {
  let field: FormFieldKey
  let value: String
  let validator: (String) -> String?
}

func updateFieldValidation(
  _ input: FieldValidationInput,
  _ fieldErrors: inout [FormFieldKey: String]
) {
  if let error = input.validator(input.value) {
    fieldErrors[input.field] = error
  } else {
    fieldErrors[input.field] = nil
  }
}
