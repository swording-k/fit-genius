#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ZH_FILE="$ROOT_DIR/FitGenius/zh-Hans.lproj/Localizable.strings"
EN_FILE="$ROOT_DIR/FitGenius/en.lproj/Localizable.strings"

required_keys=(
  form_analysis_title
  form_analysis_instruction
  form_analysis_exercise_type
  form_analysis_select_video
  form_analysis_reselect_video
  form_analysis_record_video
  form_analysis_no_camera
  form_analysis_start
  form_analysis_running
  form_analysis_score
  form_analysis_stable
  form_analysis_result
  form_analysis_coach_advice
  form_analysis_apply
  form_analysis_applied
  form_analysis_metrics
  form_analysis_close
  form_analysis_action
  form_analysis_frame_unit
  form_stats_quality_title
  form_stats_recent_title
  form_stats_average_score
  form_stats_issue_count
  form_exercise_squat
  form_exercise_deadlift
  form_exercise_bench_press
  form_metric_pose_quality
  form_metric_detected_frames
  form_metric_squat_depth_delta
  form_metric_squat_knee_cave
  form_metric_torso_lean
  form_metric_deadlift_back_angle
  form_metric_deadlift_knee_track
  form_metric_bench_elbow_flare
  form_metric_bench_asymmetry
  form_metric_bench_wrist_path
  form_metric_bench_range_of_motion
  form_metric_bench_camera_angle
  form_issue_pose_quality_low_title
  form_issue_pose_quality_low_detail
  form_issue_squat_depth_limited_title
  form_issue_squat_depth_limited_detail
  form_issue_squat_knee_cave_title
  form_issue_squat_knee_cave_detail
  form_issue_squat_torso_lean_title
  form_issue_squat_torso_lean_detail
  form_issue_deadlift_back_position_title
  form_issue_deadlift_back_position_detail
  form_issue_deadlift_knee_track_title
  form_issue_deadlift_knee_track_detail
  form_issue_bench_elbow_flare_title
  form_issue_bench_elbow_flare_detail
  form_issue_bench_press_asymmetry_title
  form_issue_bench_press_asymmetry_detail
  form_issue_bench_wrist_path_title
  form_issue_bench_wrist_path_detail
  form_issue_bench_limited_range_title
  form_issue_bench_limited_range_detail
  form_issue_bench_camera_angle_limited_title
  form_issue_bench_camera_angle_limited_detail
  form_recommendation_stable
  form_recommendation_squat
  form_recommendation_deadlift
  form_recommendation_bench
  form_note_prefix
  form_error_video_too_short
  form_error_video_too_long
  form_error_no_pose_detected
  form_error_unreadable_video
  form_error_pose_detection_unavailable
)

for key in "${required_keys[@]}"; do
  rg -q "^\"${key}\"\\s*=" "$ZH_FILE" || {
    echo "Missing zh-Hans localization key: $key"
    exit 1
  }
  rg -q "^\"${key}\"\\s*=" "$EN_FILE" || {
    echo "Missing en localization key: $key"
    exit 1
  }
done

echo "Localization check passed: ${#required_keys[@]} required keys are present in zh-Hans and en."
