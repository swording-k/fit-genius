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
                            Label("选择头像", systemImage: "photo")
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
                                Label("移除头像", systemImage: "trash")
                                    .font(.caption)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("个人信息")) {
                    HStack {
                        Text("真实姓名")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(profile.name)
                    }
                    
                    HStack {
                        Text("昵称")
                        Spacer()
                        TextField("输入昵称", text: $nicknameText)
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                    }
                }
                
                Section(header: Text("身体数据")) {
                    HStack {
                        Text("年龄")
                        Spacer()
                        Text("\(profile.age)岁")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("身高")
                        Spacer()
                        Text("\(String(format: "%.0f", profile.height))cm")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("体重")
                        Spacer()
                        Text("\(String(format: "%.1f", profile.weight))kg")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(footer: Text("如需修改身体数据，请在设置中清空数据并重新设置")) {
                    EmptyView()
                }
            }
            .navigationTitle("编辑个人资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        // 恢复原值
                        nicknameText = profile.nickname ?? ""
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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
