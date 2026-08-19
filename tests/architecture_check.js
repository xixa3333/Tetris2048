const fs = require("fs");

let passed = 0;
let failed = 0;

function test(name, callback) {
  try {
    callback();
    passed += 1;
    console.log(`PASS  ${name}`);
  } catch (error) {
    failed += 1;
    console.log(`FAIL  ${name}\n      ${error.message}`);
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function read(path) {
  return fs.readFileSync(path, "utf8");
}

test("Architecture: pure rule modules do not depend on Solar2D globals", () => {
  const forbidden = ["display.", "audio.", "timer.", "Runtime:", 'require("widget")'];
  for (const path of ["../src/board.lua", "../src/game_state.lua", "../src/game_logic.lua", "../src/pagination.lua", "../src/game_guide.lua", "../src/state_machine.lua"]) {
    const contents = read(path);
    for (const token of forbidden) assert(!contents.includes(token), `${path} contains forbidden dependency ${token}`);
  }
});

test("Architecture: controllers receive external services through dependencies", () => {
  const game = read("../src/game_controller.lua");
  const app = read("../src/app_controller.lua");
  for (const dependency of ["state", "logic", "view", "scheduler"]) assert(game.includes(`dependencies.${dependency}`), `missing game dependency ${dependency}`);
  for (const dependency of ["view", "game", "auth", "profile", "localBoard", "globalBoard", "migration", "settings", "update", "platform", "info"]) {
    assert(app.includes(`d.${dependency}`), `missing app dependency ${dependency}`);
  }
});

test("Architecture: turn phases remain separated between rules and animation orchestration", () => {
  const logic = read("../src/game_logic.lua");
  const controller = read("../src/game_controller.lua");
  for (const phase of ["moveBlocks", "clearCompleted", "placeQueuedPiece"]) {
    assert(logic.includes(`function GameLogic.${phase}`), `missing rule phase ${phase}`);
    assert(controller.includes(`self.logic.${phase}`), `controller does not orchestrate ${phase}`);
  }
  for (const forbidden of ["timer.", "transition.", "display."]) assert(!logic.includes(forbidden), `game logic contains animation dependency ${forbidden}`);
});

test("Architecture: board sliding uses shared occupancy and dependency planning", () => {
  const contents = read("../src/board.lua");
  for (const token of ["occupied", "frontEdge", "movementPlan", "dependencies"]) assert(contents.includes(token), `collision-safe slide is missing ${token}`);
});

test("Assets: every configured block image exists with neutral tile names", () => {
  const constants = read("../src/constants.lua");
  for (const name of ["tile_ember.png", "tile_sun.png", "tile_leaf.png", "tile_orchid.png", "tile_coral.png", "tile_sky.png", "tile_aqua.png"]) {
    assert(constants.includes(`image/${name}`), `constants are missing ${name}`);
    assert(fs.existsSync(`../src/image/${name}`), `block image does not exist: ${name}`);
  }
  assert(constants.includes("pieceShapes"), "shape list has not been renamed away from legacy wording");
  assert(!constants.includes("tetromino"), "constants still use protected-genre wording");
});

test("UX: tile images use a distinct rounded gem style", () => {
  const pngSignature = Buffer.from([0x89, 0x50, 0x4e, 0x47]);
  for (const name of ["tile_ember.png", "tile_sun.png", "tile_leaf.png", "tile_orchid.png", "tile_coral.png", "tile_sky.png", "tile_aqua.png", "space.png"]) {
    const data = fs.readFileSync(`../src/image/${name}`);
    assert(data.subarray(0, 4).equals(pngSignature), `${name} is not a PNG`);
    assert(data.length > 1200, `${name} is too plain for the custom rounded style`);
  }
  for (const oldName of ["T.png", "square.png", "Z.png", "S.png", "I.png", "L.png"]) {
    assert(!fs.existsSync(`../src/image/${oldName}`), `legacy shape-named asset remains packaged: ${oldName}`);
  }
  const renderer = read("../src/ui_renderer.lua");
  for (const token of ["createFrameGrid", "drawObjectOutlines", "INNER_STROKE = 1", "OUTER_STROKE = 5"]) {
    assert(renderer.includes(token), `block frame rendering is missing ${token}`);
  }
});

test("Architecture: renderer owns separate animation and overlay groups", () => {
  const contents = read("../src/ui_renderer.lua");
  for (const token of ["animationGroup", "overlayGroup", "clearTransient"]) assert(contents.includes(token), `renderer is missing ${token}`);
});

test("Mobile: Android builds declare internet permission for update checks", () => {
  const contents = read("../src/build.settings");
  assert(contents.includes("usesPermissions"), "Android permissions table is missing");
  assert(contents.includes('"android.permission.INTERNET"'), "Android internet permission is missing");
  const versionLine = contents.split("\n").find((line) => line.includes("versionCode")) || "";
  assert(!versionLine.includes("usesPermissions"), "usesPermissions was swallowed by the versionCode line");
  // Solar2D 只接受字串型別；寫成數字會被當成 unrecognized key 而整個忽略。
  assert(/versionCode\s*=\s*"\d+"/.test(contents), "android versionCode must be a quoted string");
});

test("UX: game start routes through an explicit mode selection screen", () => {
  const app = read("../src/app_controller.lua");
  const view = read("../src/app_view.lua");
  const game = read("../src/game_controller.lua");
  assert(app.includes("showModeSelect"), "app controller is missing mode selection flow");
  assert(view.includes("function AppView:showModeSelect"), "view is missing mode selection screen");
  assert(game.includes("function GameController:setMode"), "game controller cannot receive selected mode");
});

test("Architecture: settings and seeded randomness remain pure services", () => {
  for (const path of ["../src/settings_service.lua", "../src/seeded_random.lua"]) {
    const contents = read(path);
    for (const forbidden of ["display.", "native.", "audio.", "network.", 'require("widget")']) assert(!contents.includes(forbidden), `${path} contains platform dependency ${forbidden}`);
  }
});

test("Responsive UX: settings use the same letterboxed layout as the cover", () => {
  const config = read("../src/config.lua");
  const view = read("../src/app_view.lua");
  assert(config.includes('scale = "letterbox"'), "automatic device scaling is missing");
  const settingsStart = view.indexOf("function AppView:showSettings");
  assert(settingsStart >= 0, "settings screen is missing");
  assert(view.indexOf("function AppView:showSettings", settingsStart + 1) === -1, "settings screen is declared twice");
  const settingsEnd = view.indexOf("\nfunction AppView:", settingsStart + 1);
  const settings = view.slice(settingsStart, settingsEnd === -1 ? view.length : settingsEnd);
  assert(settings.includes("self:_screen"), "settings do not share the cover layout grid");
  assert(!settings.includes("widget.newScrollView"), "settings use a nested coordinate system");
});

test("Architecture: update lookup stays outside controllers and trusts a fixed release URL", () => {
  const service = read("../src/update_service.lua");
  const controller = read("../src/app_controller.lua");
  for (const forbidden of ["display.", "native.", "network.", 'require("widget")']) assert(!service.includes(forbidden), `update service contains platform dependency ${forbidden}`);
  assert(controller.includes("self.update:check"), "startup does not check for updates");
  assert(service.includes("url=self.downloadUrl"), "update prompt does not use the trusted configured URL");
  assert(service.includes("BlockMerge2048-update-check"), "update user-agent still uses the old player-facing name");
});

test("Architecture: legacy migration is isolated from UI and Solar2D", () => {
  const contents = read("../src/account_migration.lua");
  for (const dependency of ["auth", "profile", "globalBoard"]) assert(contents.includes(`self.${dependency}`), `migration is missing ${dependency}`);
  for (const forbidden of ["display.", "native.", "network.", 'require("widget")']) assert(!contents.includes(forbidden), `migration contains platform dependency ${forbidden}`);
});

test("Architecture: APP information stays platform-independent and uses HTTPS GitHub links", () => {
  const contents = read("../src/app_info.lua");
  for (const forbidden of ["display.", "native.", "system.", "network."]) assert(!contents.includes(forbidden), `APP information contains platform dependency ${forbidden}`);
  assert(!contents.includes("http://"), "APP information contains an insecure link");
  assert(contents.includes("BlockMerge 2048"), "APP information does not expose the new player-facing name");
  assert(contents.includes("https://github.com/xixa3333/Tetris2048/issues"), "issue tracker link is missing");
});

test("Architecture: Firebase configuration example contains no live secret material", () => {
  const contents = read("../src/firebase_config.example.lua").toLowerCase();
  assert(!contents.includes("password"), "Firebase configuration contains password material");
  assert(!contents.includes("private_key"), "Firebase configuration contains a private key");
  assert(!contents.includes("AIza"), "Firebase configuration example contains a live Google API key");
  const loader = read("../src/firebase_config_loader.lua");
  assert(loader.includes("firebase_config.local"), "Firebase config loader does not prefer local-only config");
  assert(loader.includes("firebase_config.example"), "Firebase config loader does not fall back to example config");
  const iosWorkflow = read("../.github/workflows/build-ios-final.yml");
  for (const secret of ["FIREBASE_PROJECT_ID", "FIREBASE_API_KEY", "FIREBASE_APP_ID"]) {
    assert(iosWorkflow.includes(secret), `iOS workflow does not generate Firebase config from ${secret}`);
  }
});

test("Privacy: remote player documents do not persist account identifiers", () => {
  const profile = read("../src/profile_service.lua");
  const leaderboard = read("../src/global_leaderboard.lua");
  const rules = read("../firebase/firestore.rules");
  assert(!profile.includes("account=stringField"), "profile persists an account identifier");
  assert(!leaderboard.includes("account=field"), "global leaderboard persists an account identifier");
  assert(!rules.includes("'account'"), "Firestore rules still permit account identifiers");
});

test("UX: current global rank and row use a brighter background", () => {
  const view = read("../src/app_view.lua");
  assert(view.includes("rankBackground"), "own-rank highlight is missing");
  assert(view.includes("rowBackground"), "current-player row highlight is missing");
  assert(view.includes("record.isCurrent"), "row highlight is not tied to the current player");
});

test("Documentation: README keeps download badge and ordered player guide", () => {
  const contents = read("../README.md");
  assert(contents.includes("img.shields.io/github/downloads/xixa3333/Tetris2048/total"), "download badge is missing");
  assert(contents.includes("# BlockMerge 2048"), "player-facing renamed title is missing");
  assert(!contents.includes("俄羅斯方塊"), "README still references a protected genre brand directly");
  assert(contents.includes("docs/images/gameplay.png"), "gameplay screenshot is missing from README");
  assert(fs.existsSync("../docs/images/gameplay.png"), "gameplay screenshot file does not exist");
  const headings = ["## 遊戲目標", "## 基本玩法", "## 得分與消除機制", "## 排行榜"];
  let previous = -1;
  for (const heading of headings) {
    const position = contents.indexOf(heading);
    assert(position > previous, `${heading} is missing or out of order`);
    previous = position;
  }
});

test("Architecture: turn and screen flow are declared as one hierarchical state machine", () => {
  const machine = read("../src/state_machine.lua");
  const game = read("../src/game_controller.lua");
  const app = read("../src/app_controller.lua");
  for (const api of ["function StateMachine:enter", "function StateMachine:dispatch", "function StateMachine:isIn"]) {
    assert(machine.includes(api), `state machine is missing ${api}`);
  }
  for (const controller of [game, app]) assert(controller.includes('require("state_machine")'), "controller does not use the shared state machine");
  assert(game.includes("TURN_STATES"), "turn phases are not declared as states");
  assert(app.includes("SCREEN_STATES"), "screens are not declared as states");
  // 輸入鎖只能由 busy 複合狀態持有，否則子狀態又會各自管理旗標。
  assert((game.match(/isBusy = /g) || []).length === 2, "the input lock is assigned outside the busy composite state");
  assert(!app.includes('self.screen="'), "screen name is assigned outside the state machine notification");
  assert(app.includes("onChange=function(owner,state) owner.screen=state end"), "screen name is not derived from the current state");
});

test("Architecture: every declared state has a known parent and a hierarchy to inherit from", () => {
  for (const [path, table, groups] of [
    ["../src/game_controller.lua", "TURN_STATES", ["turn", "busy"]],
    ["../src/app_controller.lua", "SCREEN_STATES", ["app", "menu", "identity", "leaderboard"]]
  ]) {
    const contents = read(path);
    const start = contents.indexOf(`${table} = {`) >= 0 ? contents.indexOf(`${table} = {`) : contents.indexOf(`${table}={`);
    assert(start >= 0, `${table} is missing`);
    const block = contents.slice(start, contents.indexOf("function ", start));
    const names = new Set();
    for (const match of block.matchAll(/(?:^|\n)\s{4}(\w+)\s*=\s*\{/g)) names.add(match[1]);
    for (const group of groups) assert(names.has(group), `${table} is missing composite state ${group}`);
    for (const match of block.matchAll(/parent\s*=\s*"(\w+)"/g)) {
      assert(names.has(match[1]), `${table} refers to unknown parent ${match[1]}`);
    }
    assert(/initial\s*=\s*"/.test(block), `${table} does not declare an initial child state`);
  }
});

test("UX: settings preview live and only persist when saved", () => {
  const view = read("../src/app_view.lua");
  const controller = read("../src/app_controller.lua");
  const service = read("../src/settings_service.lua");
  const settings = view.slice(view.indexOf("function AppView:showSettings"));
  assert(settings.includes("function AppView:showSettings(model,save,back,preview)"), "settings screen cannot report live changes");
  for (const control of ['apply("music")', 'apply("background")', '"effect"']) {
    assert(settings.includes(control), `settings control does not preview: ${control}`);
  }
  for (const api of ["function SettingsService:preview", "function SettingsService:revert", "function SettingsService:isPreviewing"]) {
    assert(service.includes(api), `settings service is missing ${api}`);
  }
  // 預覽不能寫入儲存，還原點只由 update 移動。
  const preview = service.slice(service.indexOf("function SettingsService:preview"), service.indexOf("function SettingsService:update"));
  assert(!preview.includes("storage:save"), "preview writes settings to storage");
  assert(controller.includes("exit=function(app) app.settings:revert() end"), "leaving the settings screen does not restore saved settings");
});

test("Architecture: no module carries a hardcoded release version", () => {
  const info = read("../src/app_info.lua");
  const current = /currentVersion = "([\d.]+)"/.exec(info);
  assert(current, "current version is missing from app information");
  for (const path of ["../src/global_leaderboard.lua", "../src/update_service.lua", "../src/app_controller.lua", "../src/game_controller.lua"]) {
    const contents = read(path);
    assert(!/"\d+\.\d+\.\d+"/.test(contents), `${path} contains a hardcoded version literal`);
  }
  assert(read("../src/global_leaderboard.lua").includes("appInfo.currentVersion"), "leaderboard does not report the running version");
  const settings = read("../src/build.settings");
  assert(settings.includes(`CFBundleShortVersionString = "${current[1]}"`), "iOS version does not match app information");
});

console.log(`Architecture result: ${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
