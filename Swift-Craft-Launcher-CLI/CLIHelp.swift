import Foundation
import Darwin

func printGlobalHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "global",
            "usage": "scl <group> <subcommand> [args] [options] [--json]"
        ])
        return
    }
    print("""
\(stylize("███████╗ ██████╗██╗          ██████╗██╗     ██╗", ANSI.bold + ANSI.cyan))
\(stylize("██╔════╝██╔════╝██║         ██╔════╝██║     ██║", ANSI.bold + ANSI.cyan))
\(stylize("███████╗██║     ██║         ██║     ██║     ██║", ANSI.bold + ANSI.cyan))
\(stylize("╚════██║██║     ██║         ██║     ██║     ██║", ANSI.bold + ANSI.cyan))
\(stylize("███████║╚██████╗███████╗    ╚██████╗███████╗██║", ANSI.bold + ANSI.cyan))
\(stylize("╚══════╝ ╚═════╝╚══════╝     ╚═════╝╚══════╝╚═╝", ANSI.bold + ANSI.cyan))

\(stylize(L("help_title"), ANSI.bold + ANSI.cyan))
\(stylize(L("help_subtitle"), ANSI.gray))

\(stylize(L("help_syntax_title"), ANSI.bold + ANSI.blue))
  \(L("help_syntax_usage"))
  \(L("help_syntax_json"))

\(stylize(L("help_groups_title"), ANSI.bold + ANSI.blue))
  set        \(L("help_group_set"))
  get        \(L("help_group_get"))
  game       \(L("help_group_game"))
  account    \(L("help_group_account"))
  resources  \(L("help_group_resources"))
  completion \(L("help_group_completion"))
  man        \(L("help_group_man"))
  lang       \(L("help_group_lang"))
  open       \(L("help_group_open"))
  uninstall  \(L("help_group_uninstall"))

\(stylize(L("help_examples_title"), ANSI.bold + ANSI.blue))
  \(L("help_example_1"))
  \(L("help_example_2"))
  \(L("help_example_3"))
  \(L("help_example_4"))
  \(L("help_example_5"))

\(stylize(L("help_more_title"), ANSI.bold + ANSI.blue))
  \(L("help_more_set"))
  \(L("help_more_get"))
  \(L("help_more_game"))
  \(L("help_more_account"))
  \(L("help_more_resources"))
  \(L("help_more_completion"))
  \(L("help_more_man"))
  \(L("help_more_lang"))
  \(L("help_more_uninstall"))
""")
}

func printCompletionHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "completion"
        ])
        return
    }
    print("""
\(stylize(L("help_completion_title"), ANSI.bold + ANSI.cyan))

\(stylize(L("help_completion_install_cmd"), ANSI.bold + ANSI.blue))
  \(L("help_completion_install_desc"))

\(stylize(L("help_completion_print_cmd"), ANSI.bold + ANSI.blue))
  \(L("help_completion_print_desc"))

\(stylize(L("help_completion_session_title"), ANSI.bold + ANSI.blue))
  \(L("help_completion_session_zsh"))
  \(L("help_completion_session_bash"))
  \(L("help_completion_session_fish"))

\(stylize(L("help_completion_persist_title"), ANSI.bold + ANSI.blue))
  zsh:
    \(L("help_completion_persist_zsh"))
  bash:
    \(L("help_completion_persist_bash"))
  fish:
    \(L("help_completion_persist_fish"))
""")
}

func printGameHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "game"
        ])
        return
    }
    print("""
\(stylize(L("help_game_title"), ANSI.bold + ANSI.cyan))

\(stylize(L("help_game_delete_cmd"), ANSI.bold + ANSI.blue))
\(L("help_game_delete_block"))

\(stylize(L("help_game_list_cmd"), ANSI.bold + ANSI.blue))
\(L("help_game_list_block"))

\(stylize(L("help_game_status_cmd"), ANSI.bold + ANSI.blue))
\(L("help_game_status_block"))

\(stylize(L("help_game_search_cmd"), ANSI.bold + ANSI.blue))
\(L("help_game_search_block"))

\(stylize(L("help_game_config_cmd"), ANSI.bold + ANSI.blue))
\(L("help_game_config_block"))

\(stylize(L("help_game_create_cmd"), ANSI.bold + ANSI.blue))
\(L("help_game_create_block"))

\(stylize(L("help_game_launch_cmd"), ANSI.bold + ANSI.blue))
\(L("help_game_launch_block"))

\(stylize(L("help_game_stop_cmd"), ANSI.bold + ANSI.blue))
\(L("help_game_stop_block"))

\(L("help_game_controls_block"))
""")
}

func printAccountHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "account"
        ])
        return
    }
    print("""
\(stylize(L("help_account_title"), ANSI.bold + ANSI.cyan))

\(stylize(L("help_account_list_cmd"), ANSI.bold + ANSI.blue))
\(L("help_account_list_block"))

\(stylize(L("help_account_create_offline_cmd"), ANSI.bold + ANSI.blue))
\(L("help_account_create_offline_block"))

\(stylize(L("help_account_create_ms_cmd"), ANSI.bold + ANSI.blue))
\(L("help_account_create_ms_block"))

\(stylize(L("help_account_delete_cmd"), ANSI.bold + ANSI.blue))
\(L("help_account_delete_block"))

\(stylize(L("help_account_set_default_cmd"), ANSI.bold + ANSI.blue))
\(L("help_account_set_default_block"))

\(stylize(L("help_account_use_cmd"), ANSI.bold + ANSI.blue))
\(L("help_account_use_block"))

\(stylize(L("help_account_show_cmd"), ANSI.bold + ANSI.blue))
\(L("help_account_show_block"))
""")
}

func printResourcesHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "resources"
        ])
        return
    }
    print("""
\(stylize(L("help_resources_title"), ANSI.bold + ANSI.cyan))

\(stylize(L("help_resources_search_cmd"), ANSI.bold + ANSI.blue))
\(L("help_resources_search_block"))

\(stylize(L("help_resources_install_cmd"), ANSI.bold + ANSI.blue))
\(L("help_resources_install_block"))

\(stylize(L("help_resources_list_cmd"), ANSI.bold + ANSI.blue))
\(L("help_resources_list_block"))

\(stylize(L("help_resources_remove_cmd"), ANSI.bold + ANSI.blue))
\(L("help_resources_remove_block"))
""")
}

func printSetHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "set"
        ])
        return
    }
    print("""
\(stylize(L("help_set_title"), ANSI.bold + ANSI.cyan))

\(stylize(L("help_set_kv_cmd"), ANSI.bold + ANSI.blue))
\(L("help_set_kv_block"))

\(stylize(L("help_set_tui_cmd"), ANSI.bold + ANSI.blue))
\(L("help_set_tui_block"))

\(stylize(L("help_set_reset_cmd"), ANSI.bold + ANSI.blue))
\(L("help_set_reset_block"))
""")
}

func printGetHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "get"
        ])
        return
    }
    print("""
\(stylize(L("help_get_title"), ANSI.bold + ANSI.cyan))

\(stylize(L("help_get_single_cmd"), ANSI.bold + ANSI.blue))
\(L("help_get_single_block"))

\(stylize(L("help_get_all_cmd"), ANSI.bold + ANSI.blue))
\(L("help_get_all_block"))
""")
}

func printUninstallHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "uninstall"
        ])
        return
    }
    print("""
\(stylize(L("help_uninstall_title"), ANSI.bold + ANSI.cyan))

\(stylize(L("help_uninstall_cli_cmd"), ANSI.bold + ANSI.blue))
\(L("help_uninstall_cli_block"))

\(stylize(L("help_uninstall_app_cmd"), ANSI.bold + ANSI.blue))
\(L("help_uninstall_app_block"))

\(stylize(L("help_uninstall_scl_cmd"), ANSI.bold + ANSI.blue))
\(L("help_uninstall_scl_block"))
""")
}

func printLangHelp() {
    if jsonOutputEnabled {
        printJSON([
            "ok": true,
            "type": "help",
            "topic": "lang"
        ])
        return
    }
    print("""
\(stylize(L("help_lang_title"), ANSI.bold + ANSI.cyan))

\(stylize(L("help_lang_list_cmd"), ANSI.bold + ANSI.blue))
\(L("help_lang_list_block"))

\(stylize(L("help_lang_set_cmd"), ANSI.bold + ANSI.blue))
\(L("help_lang_set_block"))

\(stylize(L("help_lang_show_cmd"), ANSI.bold + ANSI.blue))
\(L("help_lang_show_block"))

\(stylize(L("help_lang_path_cmd"), ANSI.bold + ANSI.blue))
\(L("help_lang_path_block"))
""")
}
