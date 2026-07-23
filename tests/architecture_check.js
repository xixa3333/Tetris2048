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
  for (const path of ["../src/board.lua", "../src/game_state.lua", "../src/game_logic.lua", "../src/pagination.lua", "../src/game_guide.lua"]) {
    const contents = read(path);
    for (const token of forbidden) {
      assert(!contents.includes(token), `${path} contains forbidden dependency ${token}`);
    }
  }
});

test("Architecture: controller receives external services through dependencies", () => {
  const contents = read("../src/game_controller.lua");
  for (const dependency of ["state", "logic", "view", "scheduler"]) {
    assert(contents.includes(`dependencies.${dependency}`), `missing injected dependency: ${dependency}`);
  }
});

test("Architecture: turn phases remain separated between rules and animation orchestration", () => {
  const logic = read("../src/game_logic.lua");
  const controller = read("../src/game_controller.lua");
  for (const phase of ["moveBlocks", "clearCompleted", "placeQueuedPiece"]) {
    assert(logic.includes(`function GameLogic.${phase}`), `missing rule phase ${phase}`);
    assert(controller.includes(`self.logic.${phase}`), `controller does not orchestrate ${phase}`);
  }
  for (const forbidden of ["timer.", "transition.", "display."]) {
    assert(!logic.includes(forbidden), `game logic contains animation dependency ${forbidden}`);
  }
});

test("Architecture: board sliding tracks a shared occupancy map", () => {
  const contents = read("../src/board.lua");
  for (const token of ["occupied", "frontEdge", "movedInPass"]) {
    assert(contents.includes(token), `collision-safe slide is missing ${token}`);
  }
});

test("Assets: every configured block image exists including the blue L tile", () => {
  const constants = read("../src/constants.lua");
  for (const name of ["T.png", "square.png", "Z.png", "S.png", "I.png", "L.png"]) {
    assert(constants.includes(`image/${name}`), `constants are missing ${name}`);
    assert(fs.existsSync(`../src/image/${name}`), `block image does not exist: ${name}`);
  }
});

test("Architecture: renderer owns separate animation and overlay groups", () => {
  const contents = read("../src/ui_renderer.lua");
  for (const token of ["animationGroup", "overlayGroup", "clearTransient"]) {
    assert(contents.includes(token), `renderer is missing ${token}`);
  }
});

test("Architecture: app flow depends on injected service contracts", () => {
  const contents = read("../src/app_controller.lua");
  for (const dependency of ["view", "game", "auth", "profile", "localBoard", "globalBoard", "platform", "info"]) {
    assert(contents.includes(`d.${dependency}`), `missing app dependency: ${dependency}`);
  }
  for (const forbidden of ["display.", "native.", "network.", 'require("widget")']) {
    assert(!contents.includes(forbidden), `app controller contains platform dependency ${forbidden}`);
  }
});

test("Architecture: APP information stays platform-independent and uses HTTPS GitHub links", () => {
  const contents = read("../src/app_info.lua");
  for (const forbidden of ["display.", "native.", "system.", "network."]) {
    assert(!contents.includes(forbidden), `APP information contains platform dependency ${forbidden}`);
  }
  assert(!contents.includes("http://"), "APP information contains an insecure link");
  assert(contents.includes("https://github.com/xixa3333/Tetris2048/issues"), "issue tracker link is missing");
});

test("Architecture: Firebase configuration contains no password or private key", () => {
  const contents = read("../src/firebase_config.lua").toLowerCase();
  assert(!contents.includes("password"), "Firebase configuration contains password material");
  assert(!contents.includes("private_key"), "Firebase configuration contains a private key");
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
  assert(contents.includes('docs/images/gameplay.png'), "gameplay screenshot is missing from README");
  assert(fs.existsSync("../docs/images/gameplay.png"), "gameplay screenshot file does not exist");
  const headings = ["## 遊戲規則", "## 得分機制", "## 遊玩方式", "## 排行榜"];
  let previous = -1;
  for (const heading of headings) {
    const position = contents.indexOf(heading);
    assert(position > previous, `${heading} is missing or out of order`);
    previous = position;
  }
});

console.log(`Architecture result: ${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
