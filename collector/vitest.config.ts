import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/**/*.{test,spec}.ts"],
    // passWithNoTests: true は T-01（スキャフォールドのみ・テスト 0 件）専用の設定。
    // 最初にテストを追加するタスク（T-02）でこの行を削除する。
    passWithNoTests: true,
  },
});
