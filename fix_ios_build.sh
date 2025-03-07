#!/bin/bash

echo "iOS ビルド問題修正スクリプト"
echo "=========================="

# プロジェクトディレクトリに移動
cd "$(dirname "$0")"

# Flutter キャッシュをクリーン
echo "Flutter キャッシュをクリーン中..."
flutter clean

# iOS ビルドファイルを削除
echo "iOS ビルドファイルを削除中..."
rm -rf ios/build
rm -rf ios/Pods
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
rm -f ios/Podfile.lock

# 依存関係を更新
echo "Flutter 依存関係を更新中..."
flutter pub get

# Runner.xcodeproj/project.pbxproj に特定の修正を適用
echo "Xcode プロジェクト設定を修正中..."
PROJECT_FILE="ios/Runner.xcodeproj/project.pbxproj"

# バックアップを作成
cp "$PROJECT_FILE" "${PROJECT_FILE}.bak"

# Bitcode 無効化
sed -i '' 's/ENABLE_BITCODE = YES;/ENABLE_BITCODE = NO;/g' "$PROJECT_FILE"

# Library for Distribution を無効化
sed -i '' 's/BUILD_LIBRARY_FOR_DISTRIBUTION = YES;/BUILD_LIBRARY_FOR_DISTRIBUTION = NO;/g' "$PROJECT_FILE"

# iOS フレームワークを再インストール
echo "iOS フレームワークを再インストール中..."
cd ios
pod install --repo-update
cd ..

echo "修正が完了しました！"
echo "次のコマンドでビルドできます: flutter run --release"
