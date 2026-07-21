package.path = "../src/?.lua;./?.lua;" .. package.path

local T = require("test_helper")
require("unit_board_test")
require("unit_game_logic_test")
require("integration_controller_test")
require("boundary_test")
require("white_box_test")
require("unit_services_test")
require("integration_app_test")
T.finish()
