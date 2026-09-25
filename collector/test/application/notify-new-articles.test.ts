// 参照する § は特記なき限り docs/design/D-02.md（§7.1）
import { describe, expect, it } from "vitest";
import type { Company } from "../../src/domain/company.js";
import { NOTIFICATION_BODY_MAX } from "../../src/domain/notification.js";
import { NotifyNewArticles } from "../../src/application/notify-new-articles.js";
import { buildArticle } from "../helpers/build-article.js";
import {
  FakeNotificationGateway,
  type FakeGatewayMode,
} from "../helpers/fake-notification-gateway.js";
import { RecordingLogger, type RecordedLogEntry } from "../helpers/recording-logger.js";

function buildCompany(overrides: Partial<Company> = {}): Company {
  return {
    id: "takarazuka",
    name: "宝塚歌劇団",
    shortName: "宝塚",
    fcmTopic: "takarazuka",
    sources: [{ kind: "html", url: "https://example.com/news" }],
    ...overrides,
  };
}

// "notification failed" の error ログだけを抽出する。複数の describe の test が同じ条件で抽出するため、
// ログの固定文言への依存箇所をファイル内 1 か所にまとめる（文言を変えたときの直し漏れを防ぐ）。
function notificationFailures(logger: RecordingLogger): RecordedLogEntry[] {
  return logger.entries.filter((e) => e.level === "error" && e.message === "notification failed");
}

describe("文面", () => {
  it("1 件で title = name・body = 見出し", async () => {
    const company = buildCompany();
    const gateway = new FakeNotificationGateway();
    const useCase = new NotifyNewArticles(gateway, new RecordingLogger());

    await useCase.execute({
      newArticlesByCompany: new Map([[company.id, [buildArticle({ title: "新公演発表" })]]]),
      companies: [company],
    });

    expect(gateway.sent).toHaveLength(1);
    const sent = gateway.sent[0];
    expect(sent?.notification).toEqual({ title: "宝塚歌劇団", body: "新公演発表" });
  });

  it("2 件で name（新着 2 件）／見出し ほか 1 件（先頭は compareArticles の先頭）", async () => {
    const company = buildCompany();
    const gateway = new FakeNotificationGateway();
    const useCase = new NotifyNewArticles(gateway, new RecordingLogger());

    await useCase.execute({
      newArticlesByCompany: new Map([
        [
          company.id,
          [
            buildArticle({ id: "1111111111111111", title: "1つ目の見出し" }),
            buildArticle({ id: "2222222222222222", title: "2つ目の見出し" }),
          ],
        ],
      ]),
      companies: [company],
    });

    const sent = gateway.sent[0];
    expect(sent?.notification).toEqual({
      title: "宝塚歌劇団（新着 2 件）",
      body: "1つ目の見出し ほか 1 件",
    });
  });

  it("data の 4 キーと apns が D-01 §4.8 どおり", async () => {
    const company = buildCompany();
    const gateway = new FakeNotificationGateway();
    const useCase = new NotifyNewArticles(gateway, new RecordingLogger());

    await useCase.execute({
      newArticlesByCompany: new Map([[company.id, [buildArticle()]]]),
      companies: [company],
    });

    const sent = gateway.sent[0];
    expect(sent?.topic).toBe(company.fcmTopic);
    expect(sent?.data).toEqual({
      schemaVersion: "1",
      type: "new_articles",
      companyId: company.id,
      count: "1",
    });
    expect(sent?.apns).toEqual({
      headers: { "apns-priority": "10" },
      payload: { aps: { sound: "default", "thread-id": company.id } },
    });
  });

  it("data.count が文字列", async () => {
    const company = buildCompany();
    const gateway = new FakeNotificationGateway();
    const useCase = new NotifyNewArticles(gateway, new RecordingLogger());

    await useCase.execute({
      newArticlesByCompany: new Map([[company.id, [buildArticle()]]]),
      companies: [company],
    });

    expect(typeof gateway.sent[0]?.data.count).toBe("string");
  });
});

describe("切り詰め", () => {
  it("130 文字・1 件 → 120 文字で「…」", async () => {
    const company = buildCompany();
    const gateway = new FakeNotificationGateway();
    const useCase = new NotifyNewArticles(gateway, new RecordingLogger());
    const longTitle = "あ".repeat(130);

    await useCase.execute({
      newArticlesByCompany: new Map([[company.id, [buildArticle({ title: longTitle })]]]),
      companies: [company],
    });

    const body = gateway.sent[0]?.notification.body ?? "";
    expect(body.length).toBe(NOTIFICATION_BODY_MAX);
    expect(body.endsWith("…")).toBe(true);
  });

  it("120 文字・2 件 → 接尾辞を残して見出し側を切る", async () => {
    const company = buildCompany();
    const gateway = new FakeNotificationGateway();
    const useCase = new NotifyNewArticles(gateway, new RecordingLogger());
    const longTitle = "い".repeat(120);

    await useCase.execute({
      newArticlesByCompany: new Map([
        [
          company.id,
          [
            buildArticle({ id: "1111111111111111", title: longTitle }),
            buildArticle({ id: "2222222222222222", title: "別の見出し" }),
          ],
        ],
      ]),
      companies: [company],
    });

    const body = gateway.sent[0]?.notification.body ?? "";
    expect(body.endsWith(" ほか 1 件")).toBe(true);
    expect(body.length).toBeLessThanOrEqual(NOTIFICATION_BODY_MAX);
    expect(body).toContain("…");
  });

  it("サロゲートペアの途中なら 1 つ手前で切る", async () => {
    const company = buildCompany();
    const gateway = new FakeNotificationGateway();
    const useCase = new NotifyNewArticles(gateway, new RecordingLogger());
    // U+1F600 (😀) はサロゲートペア。NOTIFICATION_BODY_MAX(120) - ELLIPSIS(1) = 119 文字目
    // （0-indexed 118）に高サロゲートが来るよう配置し、切断位置がペアの途中を踏むようにする
    const longTitle = "う".repeat(118) + "😀" + "え".repeat(10);

    await useCase.execute({
      newArticlesByCompany: new Map([[company.id, [buildArticle({ title: longTitle })]]]),
      companies: [company],
    });

    const body = gateway.sent[0]?.notification.body ?? "";
    // 119 文字目で切ると高サロゲート \uD83D だけが残るため、1 つ手前の 118 文字目まで切る
    // （1 つ手前で切らない場合は "う".repeat(118) + "\uD83D" + "…" という不正な単独サロゲートを含む文字列になる）
    expect(body).toBe(`${"う".repeat(118)}…`);
    expect(/\p{Surrogate}/u.test(body)).toBe(false);
  });

  it("改行・タブ・U+0000 が半角スペースに", async () => {
    const company = buildCompany();
    const gateway = new FakeNotificationGateway();
    const useCase = new NotifyNewArticles(gateway, new RecordingLogger());

    await useCase.execute({
      newArticlesByCompany: new Map([
        [company.id, [buildArticle({ title: "見出し\n改行\tタブ\u0000ヌル" })]],
      ]),
      companies: [company],
    });

    const body = gateway.sent[0]?.notification.body ?? "";
    expect(body).toBe("見出し 改行 タブ ヌル");
  });
});

describe("送信の基本", () => {
  it("新着 0 件の団体には送らない", async () => {
    const company = buildCompany();
    const gateway = new FakeNotificationGateway();
    const useCase = new NotifyNewArticles(gateway, new RecordingLogger());

    const result = await useCase.execute({
      newArticlesByCompany: new Map([[company.id, []]]),
      companies: [company],
    });

    expect(gateway.sent).toHaveLength(0);
    expect(result).toEqual({ sent: 0, failed: 0 });
  });

  it("複数団体は companies.json 順に 1 通ずつ", async () => {
    const companyA = buildCompany({ id: "takarazuka", fcmTopic: "takarazuka" });
    const companyB = buildCompany({
      id: "shiki",
      name: "劇団四季",
      shortName: "四季",
      fcmTopic: "shiki",
    });
    const gateway = new FakeNotificationGateway();
    const useCase = new NotifyNewArticles(gateway, new RecordingLogger());

    await useCase.execute({
      newArticlesByCompany: new Map([
        [companyB.id, [buildArticle({ companyId: companyB.id, title: "四季の新着" })]],
        [companyA.id, [buildArticle({ companyId: companyA.id, title: "宝塚の新着" })]],
      ]),
      companies: [companyA, companyB], // companies.json の配列順は companyA → companyB
    });

    expect(gateway.sent.map((n) => n.topic)).toEqual(["takarazuka", "shiki"]);
  });

  it("1 通の失敗で他は送られる", async () => {
    const companyA = buildCompany({ id: "takarazuka", fcmTopic: "takarazuka" });
    const companyB = buildCompany({
      id: "shiki",
      name: "劇団四季",
      shortName: "四季",
      fcmTopic: "shiki",
    });
    const gateway = new FakeNotificationGateway(new Set(["takarazuka"]));
    const logger = new RecordingLogger();
    const useCase = new NotifyNewArticles(gateway, logger);

    const result = await useCase.execute({
      newArticlesByCompany: new Map([
        [companyA.id, [buildArticle({ companyId: companyA.id })]],
        [companyB.id, [buildArticle({ companyId: companyB.id })]],
      ]),
      companies: [companyA, companyB],
    });

    expect(result).toEqual({ sent: 1, failed: 1 });
    expect(gateway.sent.map((n) => n.topic)).toEqual(["shiki"]);
    expect(notificationFailures(logger)).toHaveLength(1);
  });

  it("失敗しても再送しない", async () => {
    const company = buildCompany();
    const gateway = new FakeNotificationGateway(new Set([company.fcmTopic]));
    const useCase = new NotifyNewArticles(gateway, new RecordingLogger());

    await useCase.execute({
      newArticlesByCompany: new Map([[company.id, [buildArticle()]]]),
      companies: [company],
    });

    expect(gateway.sent).toHaveLength(0);
  });

  it("gateway.send が同期的に throw しても他団体は送られる", async () => {
    const companyA = buildCompany({ id: "takarazuka", fcmTopic: "takarazuka" });
    const companyB = buildCompany({
      id: "shiki",
      name: "劇団四季",
      shortName: "四季",
      fcmTopic: "shiki",
    });
    const gateway = new FakeNotificationGateway(new Set(["takarazuka"]), "throw");
    const logger = new RecordingLogger();
    const useCase = new NotifyNewArticles(gateway, logger);

    const result = await useCase.execute({
      newArticlesByCompany: new Map([
        [companyA.id, [buildArticle({ companyId: companyA.id })]],
        [companyB.id, [buildArticle({ companyId: companyB.id })]],
      ]),
      companies: [companyA, companyB],
    });

    expect(result).toEqual({ sent: 1, failed: 1 });
    expect(gateway.sent.map((n) => n.topic)).toEqual(["shiki"]);
  });
});

describe("全団体が reject", () => {
  // 3 団体（A・B は新着あり、C は新着 0 件）を全トピック reject の gateway に通す共通セットアップ。
  // C を混ぜるのは「新着 0 件の団体は送信対象に数えない」ことを他の 2 ケースでも保証するため。
  // mode は FakeNotificationGateway にそのまま渡す（既定 "reject" は cause を持たない
  // NotificationSendError、"reject-with-cause" は実ゲートウェイが必ず付ける cause を再現する）。
  async function executeWithAllTopicsRejected(mode: FakeGatewayMode = "reject") {
    const companyA = buildCompany({ id: "takarazuka", fcmTopic: "takarazuka" });
    const companyB = buildCompany({
      id: "shiki",
      name: "劇団四季",
      shortName: "四季",
      fcmTopic: "shiki",
    });
    const companyC = buildCompany({
      id: "toho",
      name: "東宝",
      shortName: "東宝",
      fcmTopic: "toho",
    });
    const gateway = new FakeNotificationGateway(new Set(["takarazuka", "shiki", "toho"]), mode);
    const logger = new RecordingLogger();
    const useCase = new NotifyNewArticles(gateway, logger);

    const result = await useCase.execute({
      newArticlesByCompany: new Map([
        [companyA.id, [buildArticle({ companyId: companyA.id })]],
        [companyB.id, [buildArticle({ companyId: companyB.id })]],
        [companyC.id, []], // 新着 0 件の団体は送信対象に数えない
      ]),
      companies: [companyA, companyB, companyC],
    });

    return { gateway, logger, result };
  }

  it("例外は出ず sent: 0・failed が送信対象の団体数（新着のある団体数）と一致", async () => {
    const { gateway, result } = await executeWithAllTopicsRejected();

    expect(result).toEqual({ sent: 0, failed: 2 });
    expect(gateway.sent).toHaveLength(0);
  });

  it("error ログが団体数分出る", async () => {
    const { logger } = await executeWithAllTopicsRejected();

    expect(notificationFailures(logger)).toHaveLength(2);
  });

  // FakeNotificationGateway が cause を持たない NotificationSendError で reject する
  // （mode: "reject" の既定動作）→ formatError（§4.7）は cause を再帰連結するため、cause が
  // 無ければ " <- " による連結は起きない。この test はその再帰連結が起きないこと・error フィールドが
  // 改行を含まない（1 行である）ことを固定する。実ゲートウェイ（FirebaseNotificationGateway.send）は
  // 送信失敗時に必ず cause を付けるため、この経路だけでは本番で必ず通る「cause あり」の連結を
  // 検証できない（それは直後の test が担う）。
  it('FakeNotificationGateway が cause を持たない NotificationSendError で reject する → error ログの error フィールドが 1 行で、cause 由来の連結（" <- "）を含まない', async () => {
    const { logger } = await executeWithAllTopicsRejected("reject");

    const errorEntries = notificationFailures(logger);

    expect(errorEntries).toHaveLength(2);
    for (const entry of errorEntries) {
      const error = entry.fields?.error;
      if (typeof error !== "string") throw new Error("error field must be a string");
      expect(error).toMatch(/^NotificationSendError: /);
      expect(error).not.toContain(" <- ");
      expect(error).not.toContain("\n");
    }
  });

  // 実ゲートウェイ（FirebaseNotificationGateway.send）は失敗時に必ず `{ cause: e }` を付けて
  // reject する（本番で必ず通る経路）。mode: "reject-with-cause" でそれを再現し、formatError の
  // 連結（" <- "）が起きること・それでも 1 行に収まることを同時に固定する（D-02 §4.7・§8 #48）。
  // §7.1 に無い追加ケース：§7.1 の当該ケースは「cause 由来の連結が起きないことだけを固定する」と
  // しているが、§5.4 の send() は必ず cause を付けるため、それだけでは本番経路（cause あり）が
  // 未固定になる。それを埋めるための追加で、D-02 側の追随が必要。
  it('cause 付き NotificationSendError で reject する → error フィールドが " <- " で連結され、1 行に収まる', async () => {
    const { logger } = await executeWithAllTopicsRejected("reject-with-cause");

    const errorEntries = notificationFailures(logger);

    expect(errorEntries).toHaveLength(2);
    for (const entry of errorEntries) {
      const error = entry.fields?.error;
      if (typeof error !== "string") throw new Error("error field must be a string");
      expect(error).toMatch(/^NotificationSendError: .+ <- /);
      expect(error).not.toContain("\n");
    }
  });

  it("新着 0 件の団体は failed に数えない", async () => {
    const { result } = await executeWithAllTopicsRejected();

    // toho（companyC）は新着 0 件のため送信対象から除外され、failed の 2 件は takarazuka・shiki のみ
    expect(result.failed).toBe(2);
  });
});
