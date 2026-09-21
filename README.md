# 🎯 ai-coaching-app (仮名)

**「あなたの目標達成をAIが伴走する、次世代コーチングアプリ」**

## 💡 プロジェクト概要 (About)
本アプリは、チャレキャラ（Challe-Chara）に向けて開発された目標達成支援アプリケーションです。
ユーザーが設定した目標に対して、Gemini APIが具体的なマイルストーンとタスク（ロードマップ）を自動生成し、日々のタスク実行と振り返りをサポートします。単なるタスク管理ではなく、「次に何をすべきか」をAIがコーチングしてくれるのが最大の特徴です。

## ✨ 主な機能 (Features)
- **AIロードマップ生成:** 目標を入力すると、Gemini APIがステップごとの具体的な計画を自動生成。
- **ダッシュボード:** 今日やるべきタスクと、全体のロードマップを一覧できるタイムラインUI。
- **タスク管理:** Turboを活用した、画面遷移なしのシームレスなタスク完了（チェックボックス）機能。
- **振り返り機能:** 実行したタスクに対して振り返りを行い、AIが次のステップへ向けたフィードバックを提供（実装予定）。

## 🛠 使用技術 (Tech Stack)
- **Backend:** Ruby on Rails 8.x
- **Frontend:** HTML / Tailwind CSS v4 / Hotwire (Turbo/Stimulus)
- **Database:** PostgreSQL
- **AI Integration:** Google Gemini API
- **Others:** 〇〇 (デプロイ先が決まればHerokuやRenderなどを記載)


## 🚀 ローカルでの動かし方 (Getting Started)

開発環境でアプリを動かすための手順です。

### 1. リポジトリのクローン
```bash
git clone [https://github.com/akkii0405/ai-coaching-app.git](https://github.com/ユーザー名/ai-coaching-app.git)
cd ai-coaching-app

2. 依存パッケージのインストール
Bash
bundle install

3. データベースのセットアップ
Bash
rails db:create db:migrate db:seed

4. サーバーの起動
Tailwind CSSのビルドとRailsサーバーを同時に起動します。

Bash
./bin/dev
http://localhost:3000 にアクセスして動作を確認してください。