local files = {
    "../src/board.lua",
    "../src/constants.lua",
    "../src/game_controller.lua",
    "../src/game_logic.lua",
    "../src/game_over_layout.lua",
    "../src/pagination.lua",
    "../src/game_state.lua",
    "../src/main.lua",
    "../src/movieclip.lua",
    "../src/ui_renderer.lua",
    "../src/app_controller.lua",
    "../src/app_view.lua",
    "../src/auth_service.lua",
    "../src/firebase_config.lua",
    "../src/global_leaderboard.lua",
    "../src/http_client.lua",
    "../src/input_adapter.lua",
    "../src/json_storage.lua",
    "../src/local_leaderboard.lua",
    "../src/lifecycle_adapter.lua",
    "../src/profile_service.lua",
    "../src/session_store.lua",
    "../src/config.lua",
    "../src/build.settings",
    "test_helper.lua",
    "unit_board_test.lua",
    "unit_game_logic_test.lua",
    "unit_game_over_layout_test.lua",
    "unit_pagination_test.lua",
    "integration_controller_test.lua",
    "boundary_test.lua",
    "white_box_test.lua",
    "unit_services_test.lua",
    "unit_input_adapter_test.lua",
    "unit_global_leaderboard_test.lua",
    "unit_auth_session_test.lua",
    "integration_lifecycle_test.lua",
    "security_privacy_test.lua",
    "integration_app_test.lua",
    "run.lua"
}

for _, path in ipairs(files) do
    local chunk, message = loadfile(path)
    assert(chunk, path .. ": " .. tostring(message))
end

print(("Syntax: %d Lua files compiled successfully\n"):format(#files))
