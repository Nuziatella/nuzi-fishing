local Constants = {}

Constants.ADDON_ID = "nuzi-fishing"
Constants.ADDON_NAME = "Nuzi Fishing"
Constants.ADDON_AUTHOR = "Nuzi"
Constants.ADDON_VERSION = "1.4.5"
Constants.ADDON_DESC = "Fishing coach HUD"
Constants.WARNING_TIME_SECONDS = 10
Constants.SETTINGS_FILE_PATH = "nuzi-fishing/.data/settings.txt"
Constants.LEGACY_SETTINGS_FILE_PATH = "nuzi-fishing/settings.txt"

Constants.MARKER_COUNT = 9
Constants.AUTO_CATCH_COUNT = 6
Constants.MARKER_TIMER_MS = 150000
Constants.MARKER_SCAN_MS = 250
Constants.UPDATE_INTERVAL_MS = 16
Constants.SESSION_IDLE_TIMEOUT_MS = 180000
Constants.TARGET_STABILITY_MS = 150
Constants.FRY_MAX_HP = 20000
Constants.GARGANTUAN_MIN_HP = 32000
Constants.HUD_MODE_OPTIONS = { "full", "compact" }

Constants.ACTION_BUFF_IDS = {
    [5264] = true,
    [5265] = true,
    [5266] = true,
    [5267] = true,
    [5508] = true
}

Constants.ACTION_BUFF_INFO = {
    [5264] = {
        label = "Stand Firm Right",
        coach = "RIGHT",
        hint = "The fish picked violence. Match it before it wins.",
        hotkey_actions = { "fist_fishing_action_r" }
    },
    [5265] = {
        label = "Stand Firm Left",
        coach = "LEFT",
        hint = "It juked left. Don't let it write the story.",
        hotkey_actions = { "fist_fishing_action_l" }
    },
    [5266] = {
        label = "Reel In",
        coach = "REEL IN",
        hint = "There's your opening. Rob it blind.",
        hotkey_actions = { "fist_fishing_action_reelin" },
        emphasis = "reel_in",
        sound_names = {
            "event_item_added",
            "event_explored_region",
            "event_mail_alarm"
        }
    },
    [5267] = {
        label = "Give Slack",
        coach = "SLACK",
        hint = "Easy. This is fishing, not a jury summons.",
        hotkey_actions = { "fist_fishing_action_reelout" }
    },
    [5508] = {
        label = "Big Reel In",
        coach = "BIG REEL",
        hint = "Big window. Make it regret spawning.",
        hotkey_actions = { "fist_fishing_action_up", "fist_fishing_action_reelin" },
        emphasis = "big_reel_in",
        sound_names = {
            "high_rank_achievement",
            "event_quest_completed_daily",
            "event_mail_alarm"
        }
    }
}

Constants.STRENGTH_CONTEST_BUFF_ID = 5715
Constants.OWNERS_MARK_BUFF_ID = 4867
Constants.DEAD_FISH_ICON_BUFF_ID = 4832
Constants.WAITING_ICON_BUFF_ID = 3710
Constants.DESPAWN_TRACKER_ICON_BUFF_ID = Constants.WAITING_ICON_BUFF_ID

Constants.FISH_NAMES = {
    ["Arowana"] = true,
    ["Blue Marlin"] = true,
    ["Blue Tuna"] = true,
    ["Bluefin Tuna"] = true,
    ["Carp"] = true,
    ["Eel"] = true,
    ["Marlin"] = true,
    ["Pink Marlin"] = true,
    ["Pink Pufferfish"] = true,
    ["Pufferfish"] = true,
    ["Sailfish"] = true,
    ["Sturgeon"] = true,
    ["Sunfish"] = true,
    ["Treasure Mimic"] = true,
    ["Tuna"] = true
}

Constants.TRACKED_FISH_KEYWORDS = {
    marlin = true,
    sailfish = true,
    sturgeon = true,
    sunfish = true,
    tuna = true
}

Constants.DEFAULT_SETTINGS = {
    enabled = true,
    helper_scale = 1,
    hud_mode = "full",
    target_hud_x = 760,
    target_hud_y = 360,
    session_x = 30,
    session_y = 260,
    session_button_x = 30,
    session_button_y = 212,
    session_button_size = 44,
    settings_window_x = 320,
    settings_window_y = 180,
    session_log = {
        active = false,
        current = {},
        saved = {},
        next_id = 1
    },
    show_target = true,
    show_fish_name = true,
    show_status_text = true,
    show_coach = true,
    show_coach_hint = true,
    show_keybind = true,
    show_prompt_sounds = true,
    show_markers = true,
    show_auto_catches = true,
    show_boat = true,
    show_strength = true,
    show_timers = true,
    show_wait = true,
    show_session = true,
    show_session_panel = true,
    show_target_buff_icon = false
}

return Constants
