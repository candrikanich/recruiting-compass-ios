import Foundation

/// Editable basic information for a school
/// Used in the basic info editing sheet to capture user input
struct EditableBasicInfo {
  var address: String = ""
  var baseballFacilityAddress: String = ""
  var mascot: String = ""
  var undergradSize: String = ""
  var website: String = ""
  var twitterHandle: String = ""
  var instagramHandle: String = ""

  /// Creates an EditableBasicInfo from an existing School
  /// - Parameter school: The school to extract basic info from
  /// - Returns: EditableBasicInfo populated with school data
  static func from(school: School) -> EditableBasicInfo {
    EditableBasicInfo(
      address: school.academicInfo?.address ?? "",
      baseballFacilityAddress: school.academicInfo?.baseballFacilityAddress ?? "",
      mascot: school.academicInfo?.mascot ?? "",
      undergradSize: school.academicInfo?.undergradSize ?? "",
      website: school.website ?? "",
      twitterHandle: school.twitterHandle ?? "",
      instagramHandle: school.instagramHandle ?? ""
    )
  }
}
