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
      id: "cost",
      category: "general",
      question: "How much does The Recruiting Compass cost?",
      answer: """
        It's free right now. Every family that signs up during our founding period keeps full access free \
        for life — no card, no catch. After the founding window closes, new families get a 30-day free \
        trial, then $99/year or $12.99/month for the whole family.
        """
    ),
    FaqEntry(
      id: "availability",
      category: "general",
      question: "Where can I use it?",
      answer: """
        On the web at myrecruitingcompass.com and on iPhone and iPad — download it from the App Store. \
        Same account and data everywhere.
        """
    ),
    FaqEntry(
      id: "web-vs-ios",
      category: "general",
      question: "What's the difference between the web app and the iOS app?",
      answer: """
        Same account, same data, synced automatically — use whichever is handy. The iOS app covers everyday \
        recruiting work; a few tools (reports, advanced search, recommendation letters) are web-only for \
        now.
        """
    ),
    FaqEntry(
      id: "sports",
      category: "general",
      question: "What sports do you support?",
      answer: """
        19 sports: baseball, softball, basketball, football, soccer, volleyball, beach volleyball, lacrosse, \
        field hockey, ice hockey, track & field, cross country, swimming, wrestling, rowing, water polo, \
        gymnastics, tennis, and golf. Each has sport-specific positions and performance metrics.
        """
    ),
    FaqEntry(
      id: "calendars",
      category: "coaches",
      question: "How do the recruiting calendars work?",
      answer: """
        We built 22 NCAA Division I recruiting calendars from the official 2026-27 NCAA calendars, plus \
        Division II and Division III defaults. Pick your sport and division to see contact, evaluation, \
        quiet, and dead periods — so you know when coaches can reach out, and when you should. Always \
        confirm dates with the NCAA before acting on them.
        """
    ),
    FaqEntry(
      id: "templates",
      category: "coaches",
      question: "What are the communication templates?",
      answer: """
        30+ built-in email and text templates for every stage — introductions, follow-ups, visit requests, \
        thank-you notes, and more. They fill in your name, sport, stats, and school details. Before your \
        sport's NCAA contact window opens, intro templates automatically switch to a pre-window version so \
        your first message fits the rules.
        """
    ),
    FaqEntry(
      id: "recruiting-service",
      category: "general",
      question: "Do I need to hire a recruiting service?",
      answer: """
        No. The Recruiting Compass gives you the tools to manage recruiting yourself. You'll know what to \
        do, when to do it, and how to reach out to coaches — without paying thousands for a service.
        """
    ),
    FaqEntry(
      id: "family",
      category: "family",
      question: "Can parents and athletes share an account?",
      answer: """
        Yes. Parents and athletes join one family account — by email invite or Family Code — and see the \
        same schools, coaches, interactions, and timeline. One family account can also track more than one \
        athlete; switch between them from the header.
        """
    ),
    FaqEntry(
      id: "privacy",
      category: "account",
      question: "Is my data private?",
      answer: """
        Your recruiting data is private to your family, and we don't sell it. A public player profile only \
        exists if you publish one, and you choose who gets the link. You can export your data or delete your \
        account anytime — deletion is final after 30 days, and you can cancel it before then.
        """
    ),
    FaqEntry(
      id: "too-early",
      category: "general",
      question: "I'm a freshman. Is it too early to start?",
      answer: """
        No. The recruiting timeline starts in 9th grade. The earlier you begin tracking schools and building \
        your profile, the more prepared you'll be when coaches start paying attention. Most families wish \
        they'd started sooner.
        """
    ),
    FaqEntry(
      id: "different",
      category: "general",
      question: "How is this different from other recruiting platforms?",
      answer: """
        Most options are either expensive recruiting services that do the work for you, or spreadsheets. The \
        Recruiting Compass is a management tool — structure, templates, calendars, and tracking to run your \
        own recruiting process. You stay in control.
        """
    ),
    FaqEntry(
      id: "why-no-athletic-fit",
      category: "fit-signals",
      question: "Why don't you show an Athletic Fit or Opportunity Fit score?",
      answer: """
        We intentionally don't — only a coach knows what they're looking for and what roster spots are open. \
        A fabricated score would give false confidence. Talk to the coach directly for that read.
        """
    ),
    FaqEntry(
      id: "template-hidden",
      category: "coaches",
      question: "Why did a message template change for a school?",
      answer: """
        Some sports and divisions have an NCAA contact date. Before that window opens, the intro template \
        automatically switches to a pre-window version — it's not a bug, and it never blocks outreach.
        """
    ),
    FaqEntry(
      id: "task-locked",
      category: "timeline",
      question: "Why is a task locked?",
      answer: """
        Some tasks depend on earlier ones finishing first, to keep your recruiting progression logical. \
        Complete the dependency and the lock clears automatically.
        """
    ),
    FaqEntry(
      id: "share-document",
      category: "tracking",
      question: "Why can't a school see a document I uploaded?",
      answer: """
        Uploading a document doesn't share it automatically — you choose which schools can see it. Open the \
        document and add the school under sharing.
        """
    )
  ]
}
