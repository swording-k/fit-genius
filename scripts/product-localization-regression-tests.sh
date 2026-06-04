#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if rg -q 'Text\\(steps\\[index\\]\\)' FitGenius/Views/Onboarding/OnboardingView.swift; then
  echo "FAIL: Onboarding step keys are rendered as plain strings"
  exit 1
fi

if rg -Fq -e 'String(format: "protein ' -e 'String(format: "carbs ' -e 'String(format: "fat ' \
  FitGenius/Views/Diet/DietHomeView.swift; then
  echo "FAIL: Diet summary contains hard-coded English nutrient labels"
  exit 1
fi

if rg -q 'WatchCompanionCard' FitGenius/Views/Plan; then
  echo "FAIL: Apple Watch discovery must stay out of the core training-plan flow"
  exit 1
fi

if rg -q 'Locale\\(identifier: "zh_CN"\\)' FitGenius/Views; then
  echo "FAIL: A user-facing date formatter is pinned to Chinese"
  exit 1
fi

if rg -q 'SFSpeechRecognizer\\(locale: Locale\\(identifier: "zh-CN"\\)\\)' FitGenius/Services/SpeechRecognizer.swift; then
  echo "FAIL: Speech recognition is pinned to Chinese"
  exit 1
fi

if rg -q '回答使用中文|所有内容使用中文|所有字符串使用中文|所有返回内容使用中文' FitGenius/Services/AIService.swift; then
  echo "FAIL: AI output language is pinned to Chinese"
  exit 1
fi

if rg -Fq -e 'profile.age)岁' -e 'Text("选择头像"' -e 'Text("个人信息"' -e 'Text("身体数据"' \
  FitGenius/Views/Profile/ProfileView.swift FitGenius/Views/Profile/ProfileEditorSheet.swift; then
  echo "FAIL: Profile contains hard-coded Chinese display text"
  exit 1
fi

if rg -Fq -e 'Label("清空聊天记录"' -e '.alert("清空记录"' -e 'navigationTitle("AI 饮食助手"' \
  FitGenius/Views/Assistant/AIAssistantView.swift FitGenius/Views/Diet/DietAIAssistantView.swift; then
  echo "FAIL: Assistant controls contain hard-coded Chinese display text"
  exit 1
fi

if rg -q 'dayName: todayWorkout\\.isRestDay \\? "休息日"' FitGenius/FitGeniusApp.swift; then
  echo "FAIL: Widget workout metadata is pinned to Chinese"
  exit 1
fi

if rg -Fq -e 'placeholder: "询问饮食建议' -e 'placeholder: "上传身材照' \
  FitGenius/Views/Components/EnhancedInputControlsView.swift; then
  echo "FAIL: Assistant input placeholders are pinned to Chinese"
  exit 1
fi

if rg -Fq -e 'contentText = isVideo ? "分析训练视频动作"' -e 'content = "请分析这张图片"' \
  FitGenius/ViewModels/AIAssistantViewModel.swift FitGenius/ViewModels/Diet/DietAssistantViewModel.swift; then
  echo "FAIL: New assistant system messages are pinned to Chinese"
  exit 1
fi

echo "Product localization regression tests passed"
