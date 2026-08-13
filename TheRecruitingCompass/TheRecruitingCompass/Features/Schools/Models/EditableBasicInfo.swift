import Foundation

/// Editable Contact & Social information for a school.
/// Captures the user-editable contact fields: campus address (stored in
/// academic_info), phone, website, and social handles (top-level columns).
struct EditableBasicInfo {
  var address: String = ""
  var phone: String = ""
  var website: String = ""
  var athleticsUrl: String = ""
  var twitterHandle: String = ""
  var instagramHandle: String = ""

  /// Creates an EditableBasicInfo from an existing School
  /// - Parameter school: The school to extract contact info from
  /// - Returns: EditableBasicInfo populated with school data
  static func from(school: School) -> EditableBasicInfo {
    EditableBasicInfo(
      address: school.academicInfo?.address ?? "",
      phone: school.phone ?? "",
      website: school.website ?? "",
      athleticsUrl: school.athleticsUrl ?? "",
      twitterHandle: school.twitterHandle ?? "",
      instagramHandle: school.instagramHandle ?? ""
    )
  }
}
