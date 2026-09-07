//
//  FaqEntry.swift
//  TheRecruitingCompass
//
//  Frequently asked questions, ported from web's components/Help/faqEntries.ts.
//

import Foundation

struct FaqEntry: Identifiable, Hashable {
  let id: String
  let category: String
  let question: String
  let answer: String
}

enum FaqEntries {
  static let all: [FaqEntry] = [
    FaqEntry(
      id: "why-no-athletic-fit",
      category: "fit-signals",
      question: "Why don't you show an Athletic Fit or Opportunity Fit score?",
      answer: "We intentionally don't — only a coach knows what they're looking for and what roster spots are open. A fabricated score would give false confidence. Talk to the coach directly for that read."
    ),
    FaqEntry(
      id: "template-hidden",
      category: "coaches",
      question: "Why is a message template hidden for a school?",
      answer: "Some sports and divisions have an NCAA contact period. Outside that window, the template auto-swaps to a pre-window version — it's not a bug, and it never blocks outreach entirely."
    ),
    FaqEntry(
      id: "task-locked",
      category: "timeline",
      question: "Why is a task locked?",
      answer: "Some tasks depend on earlier ones finishing first, to keep your recruiting progression logical. Complete the dependency and the lock clears automatically."
    ),
    FaqEntry(
      id: "share-document",
      category: "tracking",
      question: "Why can't a school see a document I uploaded?",
      answer: "Uploading a document doesn't share it automatically — you choose which schools can see it. Open the document and add the school under sharing."
    ),
    FaqEntry(
      id: "multiple-athletes",
      category: "family",
      question: "Can one family account track more than one athlete?",
      answer: "Yes — invite additional athletes under Family Management, and switch between them with the athlete switcher in the header."
    )
  ]
}
