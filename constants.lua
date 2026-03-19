local Constants = {}

Constants.ADDON_ID = "nuzi-fishing"
Constants.ADDON_NAME = "Nuzi Fishing"
Constants.ADDON_AUTHOR = "Nuzi"
Constants.ADDON_VERSION = "1.2.0"
Constants.ADDON_DESC = "Sport fishing helper"
Constants.WARNING_TIME_SECONDS = 10

Constants.MARKER_COUNT = 9
Constants.AUTO_CATCH_COUNT = 6
Constants.MARKER_TIMER_MS = 150000
Constants.MARKER_SCAN_MS = 250
Constants.UPDATE_INTERVAL_MS = 16

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
        hotkey_actions = { "fist_fishing_action_r" }
    },
    [5265] = {
        label = "Stand Firm Left",
        hotkey_actions = { "fist_fishing_action_l" }
    },
    [5266] = {
        label = "Reel In",
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
        hotkey_actions = { "fist_fishing_action_reelout" }
    },
    [5508] = {
        label = "Big Reel In",
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

Constants.DEFAULT_SETTINGS = {
    enabled = true,
    show_target = true,
    show_markers = true,
    show_boat = true,
    show_strength = true,
    show_timers = true,
    show_wait = true,
    show_target_buff_icon = false
}

return Constants
