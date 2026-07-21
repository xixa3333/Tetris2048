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
  for (const path of ["../src/board.lua", "../src/game_state.lua", "../src/game_logic.lua"]) {
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

test("Architecture: renderer owns separate animation and overlay groups", () => {
  const contents = read("../src/ui_renderer.lua");
  for (const token of ["animationGroup", "overlayGroup", "clearTransient"]) {
    assert(contents.includes(token), `renderer is missing ${token}`);
  }
});

console.log(`Architecture result: ${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
