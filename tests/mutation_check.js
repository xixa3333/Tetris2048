// 變異測試（mutation testing）。Lua / fengari 沒有現成工具，因此這裡自己實作：
// 在原始碼注入單一語意突變，再跑測試套件，看測試會不會失敗。
// 測試失敗代表突變被「擊殺」，測試仍然通過代表測試沒有覆蓋到那個判斷。
//
// 統計分成兩組：
//   game 遊戲內核心規則（棋盤、規則、回合狀態機）
//   app  遊戲外服務（畫面流程、排行榜、帳號、設定、更新檢查）
//
// 用法：
//   node mutation_check.js            兩組都跑（預設抽樣）
//   node mutation_check.js game       只跑遊戲內
//   node mutation_check.js app --full 跑完整突變集合，不抽樣
//   node mutation_check.js game --limit=30 --from=0 --to=15 --verbose
//     --limit 調整抽樣預算，--from/--to 分批執行，--verbose 逐筆顯示結果
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const SOURCE_DIRECTORY = path.join(__dirname, "..", "src");
const FENGARI = path.join(__dirname, "node_modules", "fengari-node-cli", "src", "lua-cli.js");
const SAMPLE_LIMIT = 60;
const RUN_TIMEOUT = 30000;

const SHARED_TESTS = ["unit_state_machine_test"];

const GROUPS = {
    game: {
        title: "遊戲內核心規則",
        sources: ["board.lua", "game_logic.lua", "game_state.lua", "game_controller.lua", "state_machine.lua"],
        tests: SHARED_TESTS.concat([
            "unit_board_test", "unit_game_logic_test", "unit_game_over_layout_test",
            "integration_controller_test", "boundary_test", "white_box_test"
        ]),
        slowTests: ["integration_autoplay_test"]
    },
    app: {
        title: "遊戲外服務",
        sources: [
            "app_controller.lua", "pagination.lua", "settings_service.lua", "update_service.lua",
            "account_identity.lua", "nickname_policy.lua", "local_leaderboard.lua",
            "global_leaderboard.lua", "audio_service.lua", "music_library.lua",
            "seeded_random.lua", "auth_service.lua", "profile_service.lua", "session_store.lua",
            "account_migration.lua", "input_adapter.lua", "lifecycle_adapter.lua"
        ],
        tests: SHARED_TESTS.concat([
            "unit_pagination_test", "unit_services_test", "integration_app_test", "unit_input_adapter_test",
            "unit_global_leaderboard_test", "unit_auth_session_test", "unit_account_identity_test",
            "unit_account_migration_test", "unit_settings_test", "unit_update_service_test",
            "unit_seeded_random_test", "unit_audio_service_test", "unit_music_library_test",
            "unit_profile_service_test", "integration_lifecycle_test", "security_privacy_test",
            "unit_app_info_test"
        ]),
        slowTests: []
    }
};

// Lua 註解與字串裡的文字不是程式邏輯，突變它們只會製造無意義的失敗。
function codeMask(source) {
    const mask = new Array(source.length).fill(true);
    let index = 0;
    const hide = (from, to) => { for (let cursor = from; cursor < to; cursor += 1) mask[cursor] = false; };
    while (index < source.length) {
        const rest = source.slice(index);
        const longBracket = /^(--)?\[(=*)\[/.exec(rest);
        if (longBracket) {
            const closing = "]" + longBracket[2] + "]";
            const end = source.indexOf(closing, index + longBracket[0].length);
            const stop = end === -1 ? source.length : end + closing.length;
            hide(index, stop); index = stop; continue;
        }
        if (rest.startsWith("--")) {
            const end = source.indexOf("\n", index);
            const stop = end === -1 ? source.length : end;
            hide(index, stop); index = stop; continue;
        }
        const quote = source[index];
        if (quote === '"' || quote === "'") {
            let cursor = index + 1;
            while (cursor < source.length && source[cursor] !== quote) {
                cursor += source[cursor] === "\\" ? 2 : 1;
            }
            hide(index, cursor + 1); index = cursor + 1; continue;
        }
        index += 1;
    }
    return mask;
}

const OPERATORS = [
    { pattern: /==/g, replacement: "~=" },
    { pattern: /~=/g, replacement: "==" },
    { pattern: />=/g, replacement: ">" },
    { pattern: /<=/g, replacement: "<" },
    { pattern: /(?<![<>=~])>(?!=)/g, replacement: ">=" },
    { pattern: /(?<![<>=~])<(?!=)/g, replacement: "<=" },
    { pattern: /\band\b/g, replacement: "or" },
    { pattern: /\bor\b/g, replacement: "and" },
    { pattern: /\btrue\b/g, replacement: "false" },
    { pattern: /\bfalse\b/g, replacement: "true" },
    { pattern: /\bnot\s+/g, replacement: "" },
    { pattern: /math\.max/g, replacement: "math.min" },
    { pattern: /math\.min/g, replacement: "math.max" },
    { pattern: /\+/g, replacement: "-" },
    // 一元負號改成加號會產生語法錯誤，因此只在二元運算的位置突變。
    { pattern: /(?<=[\w\)\]"'])\s*-(?=[\s\w\(])/g, replacement: " + " }
];

function lineOf(source, index) {
    return source.slice(0, index).split("\n").length;
}

function lineTextOf(source, index) {
    const from = source.lastIndexOf("\n", index) + 1;
    const to = source.indexOf("\n", index);
    return source.slice(from, to === -1 ? source.length : to).trim();
}

// 等價突變：語意不變，測試不可能擊殺，因此以來源片段標記並排除。
// 用程式碼片段而不是行號比對，之後檔案增刪行也不會失效。
const EQUIVALENT = [
    {file: "board.lua", from: "true", to: "false", code: "plan.dependencies[owner] = true",
        reason: "dependencies 只用到 key，值本身不會被讀取"},
    {file: "board.lua", from: "false", to: "true", code: "if visiting[component] then memo[component] = false",
        reason: "單一方向滑動不會產生相依環，這是防禦性分支"},
    {file: "board.lua", from: ">", to: ">=", code: 'if direction == "down" or direction == "right" then return aEdge > bEdge end',
        reason: "上一行已處理 aEdge == bEdge，>= 與 > 在此等價"},
    {file: "board.lua", from: ">", to: ">=", code: "and coordinate > edge",
        reason: "coordinate 等於 edge 時重新指派同一個值，結果不變"},
    {file: "board.lua", from: "<", to: "<=", code: "and coordinate < edge",
        reason: "coordinate 等於 edge 時重新指派同一個值，結果不變"},
    {file: "game_logic.lua", from: "-", to: "+", code: "for row = 1, constants.ROWS - #shape + 1 do",
        reason: "掃描範圍放大只會多跑無效座標，canPlace 仍會擋下，結果相同"},
    {file: "game_logic.lua", from: "-", to: "+", code: "for column = 1, constants.COLS - #shape[1] + 1 do",
        reason: "掃描範圍放大只會多跑無效座標，canPlace 仍會擋下，結果相同"},
    {file: "game_logic.lua", from: "-", to: "+", code: "for offset = 0, #placements - 1 do",
        reason: "多跑一圈只是重試同一個候選位置，棋盤沒有改變所以結果相同"},
    {file: "local_leaderboard.lua", from: ">", to: ">=", code: "return a.score > b.score",
        reason: "上一行已處理分數相同的情況，>= 與 > 在此等價"},
    {file: "input_adapter.lua", from: ">", to: ">=", code: 'return dx > 0 and "right" or "left"', before: "return dx ",
        reason: "dx 為 0 時不會進到水平分支，>= 與 > 等價"},
    {file: "input_adapter.lua", from: ">", to: ">=", code: 'return dy > 0 and "down" or "up"', before: "return dy ",
        reason: "dy 為 0 時位移未超過門檻，已提早回傳 nil"},
    {file: "audio_service.lua", from: "or", to: "and", code: "setting=setting or self.settings:get()",
        reason: "兩個呼叫端傳入的都是當下的 settings:get()，兩種寫法取到同一份設定"}
];

function isEquivalent(mutation) {
    return EQUIVALENT.some((entry) => entry.file === mutation.file && entry.from === mutation.from
        && entry.to === mutation.to && mutation.text.includes(entry.code)
        // 同一行有多個相同運算子時，用前綴區分要排除的是哪一個。
        && (entry.before === undefined || mutation.before.includes(entry.before)));
}

function mutationsFor(name, source) {
    const mask = codeMask(source);
    const mutations = [];
    for (const { pattern, replacement } of OPERATORS) {
        pattern.lastIndex = 0;
        let match;
        while ((match = pattern.exec(source)) !== null) {
            const start = match.index;
            const end = start + match[0].length;
            let inCode = true;
            for (let cursor = start; cursor < end; cursor += 1) if (!mask[cursor]) inCode = false;
            if (inCode) {
                mutations.push({
                    file: name, line: lineOf(source, start), text: lineTextOf(source, start),
                    before: source.slice(Math.max(0, start - 16), start),
                    from: match[0].trim() || match[0], to: replacement.trim() || "(removed)",
                    mutated: source.slice(0, start) + replacement + source.slice(end)
                });
            }
        }
    }
    mutations.sort((left, right) => left.line - right.line);
    return mutations;
}

// 固定步長抽樣：同一份原始碼永遠得到同一組突變，報告才能逐次比較。
function sample(mutations, full) {
    const limit = option("limit", SAMPLE_LIMIT);
    const ordered = mutations.slice().sort((left, right) =>
        left.file === right.file ? left.line - right.line : left.file < right.file ? -1 : 1);
    if (full || ordered.length <= limit) return ordered;
    const step = ordered.length / limit;
    const picked = [];
    for (let index = 0; index < limit; index += 1) picked.push(ordered[Math.floor(index * step)]);
    return picked;
}

function prepareWorkspace(group, full) {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "blockmerge-mutation-"));
    fs.mkdirSync(path.join(root, "src"));
    fs.mkdirSync(path.join(root, "tests"));
    for (const name of fs.readdirSync(SOURCE_DIRECTORY)) {
        if (name.endsWith(".lua")) fs.copyFileSync(path.join(SOURCE_DIRECTORY, name), path.join(root, "src", name));
    }
    for (const name of fs.readdirSync(__dirname)) {
        if (name.endsWith(".lua")) fs.copyFileSync(path.join(__dirname, name), path.join(root, "tests", name));
    }
    const modules = group.tests.concat(full ? group.slowTests : []);
    const runner = ['package.path = "../src/?.lua;./?.lua;" .. package.path', 'local T = require("test_helper")']
        .concat(modules.map((name) => `require("${name}")`))
        .concat(["T.finish()"]).join("\n");
    fs.writeFileSync(path.join(root, "tests", "mutation_run.lua"), runner);
    return root;
}

function runSuite(root) {
    const result = spawnSync(process.execPath, [FENGARI, "mutation_run.lua"], {
        cwd: path.join(root, "tests"), encoding: "utf8", timeout: RUN_TIMEOUT
    });
    // 讓迴圈永遠跑不完的突變也算被擊殺：正常程式不會超時。
    if (result.error && result.error.code === "ETIMEDOUT") return {passed: false, summary: "timeout"};
    const output = (result.stdout || "") + (result.stderr || "");
    const summary = /Result: (\d+) passed, (\d+) failed/.exec(output);
    return {
        passed: result.status === 0 && summary !== null && Number(summary[2]) === 0,
        summary: summary ? `${summary[1]} passed, ${summary[2]} failed` : "crashed"
    };
}

function runGroup(key, full) {
    const group = GROUPS[key];
    const root = prepareWorkspace(group, full);
    const baseline = runSuite(root);
    if (!baseline.passed) {
        console.log(`FAIL  ${key} 基準測試未通過（${baseline.summary}），變異測試中止`);
        return { key, killed: 0, survived: [], total: 0, ok: false };
    }
    const originals = {};
    let candidates = [];
    for (const name of group.sources) {
        const file = path.join(root, "src", name);
        originals[name] = fs.readFileSync(file, "utf8");
        candidates = candidates.concat(mutationsFor(name, originals[name]).filter((mutation) => !isEquivalent(mutation)));
    }
    // 抽樣以整組為單位，讓每個檔案都被覆蓋到，而不是把預算耗在最長的檔案上。
    const selected = sample(candidates, full).slice(option("from", 0), option("to", Infinity));
    const survived = [];
    let killed = 0;
    let total = 0;
    for (const mutation of selected) {
        const file = path.join(root, "src", mutation.file);
        total += 1;
        fs.writeFileSync(file, mutation.mutated);
        const attempt = runSuite(root);
        if (attempt.passed) survived.push(mutation); else killed += 1;
        fs.writeFileSync(file, originals[mutation.file]);
        if (verbose) {
            console.log(`  ${total}/${selected.length} ${attempt.passed ? "SURVIVED" : "killed  "} ` +
                `${mutation.file}:${mutation.line} ${mutation.from} -> ${mutation.to}`);
        }
    }
    fs.rmSync(root, { recursive: true, force: true });
    const score = total === 0 ? 100 : (killed / total) * 100;
    console.log(`\n[${key}] ${group.title}`);
    console.log(`  已排除等價突變 ${EQUIVALENT.length} 筆`);
    console.log(`  突變數 ${total}，擊殺 ${killed}，存活 ${survived.length}，擊殺率 ${score.toFixed(1)}%`);
    for (const mutation of survived) {
        console.log(`  SURVIVED  ${mutation.file}:${mutation.line}  ${mutation.from} -> ${mutation.to}`);
    }
    return { key, killed, survived, total, score, ok: true };
}

function option(name, fallback) {
    const found = process.argv.find((value) => value.startsWith(`--${name}=`));
    return found ? Number(found.split("=")[1]) : fallback;
}
const requested = process.argv.slice(2).filter((value) => !value.startsWith("--"));
const full = process.argv.includes("--full");
const verbose = process.argv.includes("--verbose");
const keys = requested.length > 0 ? requested : Object.keys(GROUPS);
let failed = false;
const results = [];
for (const key of keys) {
    if (!GROUPS[key]) { console.log(`unknown group: ${key}`); process.exit(1); }
    const result = runGroup(key, full);
    results.push(result);
    if (!result.ok) failed = true;
}
console.log("\nMutation result:");
for (const result of results) {
    if (!result.ok) continue;
    console.log(`  ${result.key}: ${result.killed}/${result.total} killed (${result.score.toFixed(1)}%)`);
    if (result.survived.length > 0) failed = true;
}
if (failed) { console.log("\n仍有存活突變，請補強測試或標記為等價突變。"); process.exit(1); }
console.log("\n所有突變都被測試擊殺。");
