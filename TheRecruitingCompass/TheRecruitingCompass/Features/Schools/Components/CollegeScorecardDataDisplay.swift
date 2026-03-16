//
//  CollegeScorecardDataDisplay.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11
//  Phase 3: Display College Scorecard academic data
//

import SwiftUI

struct CollegeScorecardDataDisplay: View {
  let data: CollegeDataResult

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Section Header
      HStack {
        Image(systemName: "chart.bar.fill")
          .foregroundStyle(.blue)
          .accessibilityHidden(true)

        Text("College Scorecard Data")
          .font(.headline)
          .foregroundStyle(.primary)
      }

      // Data Grid
      LazyVGrid(
        columns: [
          GridItem(.flexible(), spacing: 12),
          GridItem(.flexible(), spacing: 12)
        ],
        spacing: 12
      ) {
        // Student Size
        if let studentSize = data.studentSize {
          dataItem(
            label: "Student Size",
            value: formatNumber(studentSize),
            icon: "person.3.fill"
          )
        }

        // Total Enrollment (web: enrollmentAll)
        if let enrollmentAll = data.enrollmentAll {
          dataItem(
            label: "Total Enrollment",
            value: formatNumber(enrollmentAll),
            icon: "person.3.fill"
          )
        }

        // Size Category
        if let sizeCategory = data.carnegieSize {
          dataItem(
            label: "Size Category",
            value: sizeCategory,
            icon: "chart.pie.fill"
          )
        }

        // Admission Rate
        if let admissionRate = data.admissionRate {
          dataItem(
            label: "Admission Rate",
            value: formatPercentage(admissionRate),
            icon: "checkmark.seal.fill"
          )
        }

        // Student-Faculty Ratio (web: studentFacultyRatio)
        if let ratio = data.studentFacultyRatio {
          dataItem(
            label: "Student-Faculty Ratio",
            value: "\(ratio.formatted(.number.precision(.fractionLength(1)))):1",
            icon: "person.2.fill"
          )
        }

        // Tuition In-State
        if let tuition = data.tuitionInState {
          dataItem(
            label: "Tuition (In-State)",
            value: formatCurrency(Int(tuition)),
            icon: "dollarsign.circle.fill"
          )
        }

        // Tuition Out-of-State
        if let tuition = data.tuitionOutOfState {
          dataItem(
            label: "Tuition (Out-of-State)",
            value: formatCurrency(Int(tuition)),
            icon: "dollarsign.circle.fill"
          )
        }

        // Avg Net Price
        if let avgNetPrice = data.avgNetPrice {
          dataItem(
            label: "Avg Net Price",
            value: "\(formatCurrency(avgNetPrice))/yr",
            icon: "dollarsign.circle.fill"
          )
        }

        // Graduation Rate
        if let graduationRate = data.graduationRate {
          dataItem(
            label: "Graduation Rate",
            value: "\(Int(graduationRate * 100))%",
            icon: "graduationcap.fill"
          )
        }

        // Map Coordinates
        if data.latitude != nil && data.longitude != nil {
          dataItem(
            label: "Location",
            value: "✓ Map coordinates available",
            icon: "map.fill"
          )
        }
      }
    }
    .padding()
    .background(Color.blue.opacity(0.05))
    .clipShape(.rect(cornerRadius: 8))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("College Scorecard academic data")
  }

  // MARK: - Data Item

  private func dataItem(label: String, value: String, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .font(.caption)
          .foregroundStyle(.blue)
          .accessibilityHidden(true)

        Text(label)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Text(value)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.primary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(UIColor.systemBackground))
    .clipShape(.rect(cornerRadius: 6))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(value)")
  }

  // MARK: - Formatters

  private func formatNumber(_ number: Int) -> String {
    number.formatted(.number)
  }

  private func formatPercentage(_ decimal: Double) -> String {
    decimal.formatted(.percent.precision(.fractionLength(1)))
  }

  private func formatCurrency(_ amount: Int) -> String {
    amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")
      .precision(.fractionLength(0)))
  }
}

// MARK: - Preview

#Preview {
  ScrollView {
    CollegeScorecardDataDisplay(
      data: CollegeDataResult(
        id: "134130",
        name: "University of Florida",
        website: "https://ufl.edu",
        address: "Gainesville, FL",
        city: "Gainesville",
        state: "FL",
        studentSize: 52218,
        carnegieSize: "Large",
        admissionRate: 0.296,
        tuitionInState: 6381.0,
        tuitionOutOfState: 28658.0,
        avgNetPrice: 14200,
        graduationRate: 0.88,
        latitude: 29.6516,
        longitude: -82.3248
      )
    )
    .padding()
  }
}
