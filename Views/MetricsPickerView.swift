// MetricsPickerView.swift
// Premium Apple HIG-style metric management picker

import SwiftUI

struct MetricsPickerView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    private var canDisable: Bool {
        appState.enabledMetrics.count > 1
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // MARK: - Primary Metrics Section

                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader(L10n.string("核心指标"))

                        VStack(spacing: 0) {
                            ForEach(BodyMetricType.allCases.filter { $0.category == .primary }) { metric in
                                metricRow(metric: metric)
                                if metric != BodyMetricType.allCases.filter({ $0.category == .primary }).last {
                                    separator
                                }
                            }
                        }
                        .blCard()
                    }

                    // MARK: - Measurement Metrics Section

                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader(L10n.string("围度测量"))

                        let measurements = BodyMetricType.allCases.filter { $0.category == .measurement }
                        VStack(spacing: 0) {
                            ForEach(Array(measurements.enumerated()), id: \.element.id) { index, metric in
                                metricRow(metric: metric)
                                if index < measurements.count - 1 {
                                    separator
                                }
                            }
                        }
                        .blCard()
                    }

                    // MARK: - Footer

                    footerInfo
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.formlogBgGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.string("取消")) { isPresented = false }
                        .font(.blBody)
                        .foregroundColor(.formlogBlue)
                }
                ToolbarItem(placement: .principal) {
                    Text(L10n.string("管理指标"))
                        .font(.blBodySemibold)
                        .foregroundColor(.formlogTextPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("完成")) {
                        BodyLogHaptics.medium()
                        appState.save()
                        isPresented = false
                    }
                    .font(.blBodySemibold)
                    .foregroundColor(.formlogPrimary)
                }
            }
            .blNavigationBar()
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.formlogTextSecondary)
            .tracking(0.08)
            .padding(.leading, 4)
    }

    // MARK: - Metric Row

    private func metricRow(metric: BodyMetricType) -> some View {
        let isEnabled = appState.enabledMetrics.contains(metric)

        return HStack(spacing: 12) {
            // Colored icon circle
            Circle()
                .fill(metric.color.opacity(0.12))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: metric.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(metric.color)
                )

            // Name + unit
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.displayName)
                    .font(.blBody)
                    .foregroundColor(isEnabled ? .formlogTextPrimary : .formlogTextSecondary)

                if !metric.unit.isEmpty {
                    Text(metric.unit)
                        .font(.blCaption1)
                        .foregroundColor(.formlogTextTertiary)
                }
            }

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in toggleMetric(metric) }
            ))
            .labelsHidden()
            .tint(.formlogPrimary)
            .disabled(!canDisable && isEnabled)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .contentShape(Rectangle())
    }

    // MARK: - Separator

    private var separator: some View {
        Divider()
            .padding(.leading, 58)
            .foregroundColor(.formlogSeparator)
    }

    // MARK: - Footer

    private var footerInfo: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.formlogTextTertiary)

            Text(L10n.string("至少保留一个指标"))
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.formlogTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - Toggle Logic

    private func toggleMetric(_ metric: BodyMetricType) {
        BodyLogHaptics.light()
        if let index = appState.enabledMetrics.firstIndex(of: metric) {
            guard appState.enabledMetrics.count > 1 else { return }
            appState.enabledMetrics.remove(at: index)
        } else {
            appState.enabledMetrics.append(metric)
        }
    }
}

#Preview {
    MetricsPickerView(isPresented: .constant(true))
        .environmentObject(AppState.shared)
}
