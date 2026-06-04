import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 用户头像和昵称编辑器
struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var nicknameText: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // 头像编辑
                    VStack(spacing: 16) {
                        if let avatarData = profile.avatarData,
                           let uiImage = UIImage(data: avatarData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 100))
                                .foregroundColor(.gray)
                        }
                        
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("select_avatar", systemImage: "photo")
                                .font(.headline)
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let newItem = newItem,
                                   let data = try? await newItem.loadTransferable(type: Data.self) {
                                    // 压缩图片
                                    if let image = UIImage(data: data),
                                       let compressed = image.jpegData(compressionQuality: 0.7) {
                                        profile.avatarData = compressed
                                        try? modelContext.save()
                                    }
                                }
                            }
                        }
                        
                        if profile.avatarData != nil {
                            Button(role: .destructive) {
                                profile.avatarData = nil
                                try? modelContext.save()
                            } label: {
                                Label("remove_avatar", systemImage: "trash")
                                    .font(.caption)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("personal_information")) {
                    HStack {
                        Text("real_name")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(profile.name)
                    }
                    
                    HStack {
                        Text("nickname")
                        Spacer()
                        TextField("enter_nickname", text: $nicknameText)
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                    }
                }
                
                Section(header: Text("body_data")) {
                    HStack {
                        Text("age")
                        Spacer()
                        Text("profile_age_format".localized(with: profile.age))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("height")
                        Spacer()
                        Text("\(String(format: "%.0f", profile.height))cm")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("weight")
                        Spacer()
                        Text("\(String(format: "%.1f", profile.weight))kg")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(footer: Text("profile_body_data_edit_hint")) {
                    EmptyView()
                }
            }
            .navigationTitle("edit_profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        // 恢复原值
                        nicknameText = profile.nickname ?? ""
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        profile.nickname = nicknameText.isEmpty ? nil : nicknameText
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                nicknameText = profile.nickname ?? ""
            }
        }
    }
}
