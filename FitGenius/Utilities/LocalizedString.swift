//
//  LocalizedString.swift
//  FitGenius
//
//  Localization helper for multi-language support
//

import SwiftUI

// MARK: - String Extension for Localization
extension String {
    /// 本地化字符串（使用key本身作为显示）
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    /// 带参数的本地化字符串
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Localized Text
/// 用于SwiftUI Text视图的本地化
func localized(_ key: String) -> Text {
    return Text(LocalizedStringKey(key))
}

// MARK: - Localized Label
/// 用于SwiftUI Label的本地化
func localizedLabel(_ key: String, systemImage: String) -> Label<Text, Image> {
    return Label {
        Text(LocalizedStringKey(key))
    } icon: {
        Image(systemName: systemImage)
    }
}

// MARK: - Helper for tabs
extension View {
    /// 设置tab标签
    func tabLabel(_ key: String, systemImage: String) -> some View {
        self.tabItem {
            Label {
                Text(LocalizedStringKey(key))
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }
}
