//
//  GlossaryTerm.swift
//  TheRecruitingCompass
//
//  Recruiting glossary terms, ported from web's components/Help/glossaryTerms.ts.
//

import Foundation

struct GlossaryTerm: Identifiable, Hashable {
  let id: String
  let term: String
  let definition: String
}

enum GlossaryTerms {
  static let all: [GlossaryTerm] = rawTerms.sorted { $0.term.localizedStandardCompare($1.term) == .orderedAscending }

  private static let rawTerms: [GlossaryTerm] = [
    GlossaryTerm(
      id: "committable",
      term: "Committable Offer",
      definition: "A scholarship or roster-spot offer the athlete can accept, as opposed to general interest."
    ),
    GlossaryTerm(
      id: "dead-period",
      term: "Dead Period",
      definition: "An NCAA-defined window when a coach cannot have any in-person contact with a recruit, on or off campus."
    ),
    GlossaryTerm(
      id: "eval-period",
      term: "Evaluation Period",
      definition: "An NCAA-defined window when a coach may watch a recruit compete or visit their school, but off-campus, in-person recruiting contact is not allowed."
    ),
    GlossaryTerm(
      id: "grayshirt",
      term: "Grayshirting",
      definition: "Delaying enrollment (and scholarship start) by a semester or year, usually to manage a roster's scholarship count."
    ),
    GlossaryTerm(
      id: "letter-of-intent",
      term: "Letter of Intent (LOI)",
      definition: "A binding written agreement between a recruit and a school confirming enrollment and athletic participation."
    ),
    GlossaryTerm(
      id: "official-visit",
      term: "Official Visit",
      definition: "A campus visit paid for (in full or part) by the school, limited to 5 total across a recruit's official visits, one per school."
    ),
    GlossaryTerm(
      id: "preferred-walk-on",
      term: "Preferred Walk-On",
      definition: "A roster spot offered without a scholarship, but with an implicit invitation to try out rather than compete in open tryouts."
    ),
    GlossaryTerm(
      id: "quiet-period",
      term: "Quiet Period",
      definition: "An NCAA-defined window when a coach may only have recruiting contact with a recruit on the school's own campus."
    ),
    GlossaryTerm(
      id: "recruiting-calendar",
      term: "Recruiting Calendar",
      definition: "The NCAA's sport-specific schedule of contact, evaluation, quiet, and dead periods that governs when a coach can contact a recruit."
    ),
    GlossaryTerm(
      id: "redshirt",
      term: "Redshirt",
      definition: "A season in which an athlete practices with the team but doesn't compete, preserving a year of eligibility."
    ),
    GlossaryTerm(
      id: "unofficial-visit",
      term: "Unofficial Visit",
      definition: "A self-funded campus visit with no limit on how many a recruit can take."
    ),
    GlossaryTerm(
      id: "walk-on",
      term: "Walk-On",
      definition: "An athlete who joins a team without an athletic scholarship, typically via open tryouts."
    )
  ]
}
