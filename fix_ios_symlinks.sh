#!/bin/bash

# Flutter プロジェクトのリセットスクリプト
# iOS の .symlinks 問題を解決する

echo "Flutter プロジェクトの依存関係を修復しています..."

# iOS関連のキャッシュをクリーンアップ
echo "iOS シンボリックリンクを削除中..."
rm -rf ios/.symlinks
rm -rf ios/Pods
rm -rf ios/Podfile.lock

# Flutter キャッシュをクリア
echo "Flutter キャッシュをクリア中..."
flutter clean

# 依存関係を更新
echo "パッケージを更新中..."
flutter pub get

# iOS設定を再生成
echo "iOS設定を再生成中..."
cd ios
pod install --repo-update
cd ..

echo "完了! ビルドを実行してください: flutter run"
