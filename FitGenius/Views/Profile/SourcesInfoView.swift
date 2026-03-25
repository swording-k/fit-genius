import SwiftUI

struct SourceItem: Identifiable {
    let id = UUID()
    let nameKey: String
    let url: String
}

struct SourceCategory: Identifiable {
    let id = UUID()
    let titleKey: String
    let icon: String
    let color: Color
    let sources: [SourceItem]
}

struct SourcesInfoView: View {
    @Environment(\.dismiss) private var dismiss

    private let categories: [SourceCategory] = [
        SourceCategory(
            titleKey: "nutrition_sources",
            icon: "leaf.fill",
            color: .green,
            sources: [
                SourceItem(nameKey: "source_china_nutrition", url: "https://www.cnsoc.org.cn"),
                SourceItem(nameKey: "source_usda", url: "https://www.nal.usda.gov/food"),
                SourceItem(nameKey: "source_nih", url: "https://www.nih.gov/health-information")
            ]
        ),
        SourceCategory(
            titleKey: "exercise_science_sources",
            icon: "figure.run",
            color: .blue,
            sources: [
                SourceItem(nameKey: "source_acsm", url: "https://www.acsm.org"),
                SourceItem(nameKey: "source_nsca", url: "https://www.nsca.com")
            ]
        ),
        SourceCategory(
            titleKey: "general_health_sources",
            icon: "heart.fill",
            color: .red,
            sources: [
                SourceItem(nameKey: "source_who", url: "https://www.who.int/news-room/fact-sheets"),
                SourceItem(nameKey: "source_cdc", url: "https://www.cdc.gov/nutrition")
            ]
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("sources_intro")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    ForEach(categories) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Label(category.titleKey.localized, systemImage: category.icon)
                                .font(.headline)
                                .foregroundColor(category.color)
                                .padding(.horizontal)

                            ForEach(category.sources) { source in
                                Link(destination: URL(string: source.url)!) {
                                    HStack {
                                        Text(source.nameKey.localized)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // 免责声明
                    VStack(alignment: .leading, spacing: 8) {
                        Text("sources_disclaimer_title")
                            .font(.headline)
                            .foregroundColor(.orange)

                        Text("sources_disclaimer")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("data_sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SourcesInfoView()
}
