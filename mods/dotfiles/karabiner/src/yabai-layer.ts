import { map, rule, simlayer, to$ } from "karabiner.ts";

export const yabaiLayerRules = [
  simlayer("s", "yabai: window focus & navigation").manipulators([
    map("h").to$(
      "yabai -m window --focus west"
    ),
    map("j").to$(
      "yabai -m window --focus south"
    ),
    map("k").to$(
      "yabai -m window --focus north"
    ),
    map("l").to$(
      "yabai -m window --focus east"
    ),
    map("n").to$(
      "yabai -m window --focus next"
    ),
    map("p").to$(
      "yabai -m window --focus prev"
    ),
    map("m").to$(
      "yabai -m window --focus largest"
    ),
    map("r").to$(
      "yabai -m window --focus recent"
    ),
    map("open_bracket").to$(
      "yabai -m display --focus prev"
    ),
    map("close_bracket").to$(
      "yabai -m display --focus next"
    ),
  ]),

  simlayer("d", "yabai: window movement & manipulation").manipulators([
    map("h").to$(
      "yabai -m window --swap west"
    ),
    map("j").to$(
      "yabai -m window --swap south"
    ),
    map("k").to$(
      "yabai -m window --swap north"
    ),
    map("l").to$(
      "yabai -m window --swap east"
    ),
    map("h", { mandatory: ["shift"] }).to$(
      "yabai -m window --warp west"
    ),
    map("j", { mandatory: ["shift"] }).to$(
      "yabai -m window --warp south"
    ),
    map("k", { mandatory: ["shift"] }).to$(
      "yabai -m window --warp north"
    ),
    map("l", { mandatory: ["shift"] }).to$(
      "yabai -m window --warp east"
    ),
    map("n").to$(
      "yabai -m window --swap next"
    ),
    map("p").to$(
      "yabai -m window --swap prev"
    ),
    map("spacebar").to$(
      "yabai -m window --toggle float"
    ),
    map("f").to$(
      "yabai -m window --toggle zoom-fullscreen"
    ),
    map("z").to$(
      "yabai -m window --toggle zoom-parent"
    ),
    map("s").to$(
      "yabai -m window --toggle split"
    ),
    map("r").to$(
      "yabai -m space --rotate 90"
    ),
    map("b").to$(
      "yabai -m space --balance"
    ),
    map("x").to$(
      "yabai -m space --mirror x-axis"
    ),
    map("y").to$(
      "yabai -m space --mirror y-axis"
    ),
  ]),

  simlayer("f", "yabai: space & display management").manipulators([
    map("h").to$(
      "yabai -m window --resize left:-50:0"
    ),
    map("j").to$(
      "yabai -m window --resize bottom:0:50"
    ),
    map("k").to$(
      "yabai -m window --resize top:0:-50"
    ),
    map("l").to$(
      "yabai -m window --resize right:50:0"
    ),
    map("n").to$(
      "yabai -m space --focus next || yabai -m space --focus first"
    ),
    map("p").to$(
      "yabai -m space --focus prev || yabai -m space --focus last"
    ),
    map("open_bracket").to$(
      "yabai -m window --space prev && yabai -m space --focus prev"
    ),
    map("close_bracket").to$(
      "yabai -m window --space next && yabai -m space --focus next"
    ),
    map("1").to$(
      "yabai -m space --focus 1"
    ),
    map("2").to$(
      "yabai -m space --focus 2"
    ),
    map("3").to$(
      "yabai -m space --focus 3"
    ),
    map("4").to$(
      "yabai -m space --focus 4"
    ),
    map("5").to$(
      "yabai -m space --focus 5"
    ),
    map("6").to$(
      "yabai -m space --focus 6"
    ),
    map("7").to$(
      "yabai -m space --focus 7"
    ),
    map("8").to$(
      "yabai -m space --focus 8"
    ),
    map("9").to$(
      "yabai -m space --focus 9"
    ),
    map("1", { mandatory: ["shift"] }).to$(
      "yabai -m window --space 1 && yabai -m space --focus 1"
    ),
    map("2", { mandatory: ["shift"] }).to$(
      "yabai -m window --space 2 && yabai -m space --focus 2"
    ),
    map("3", { mandatory: ["shift"] }).to$(
      "yabai -m window --space 3 && yabai -m space --focus 3"
    ),
    map("4", { mandatory: ["shift"] }).to$(
      "yabai -m window --space 4 && yabai -m space --focus 4"
    ),
    map("5", { mandatory: ["shift"] }).to$(
      "yabai -m window --space 5 && yabai -m space --focus 5"
    ),
    map("6", { mandatory: ["shift"] }).to$(
      "yabai -m window --space 6 && yabai -m space --focus 6"
    ),
    map("7", { mandatory: ["shift"] }).to$(
      "yabai -m window --space 7 && yabai -m space --focus 7"
    ),
    map("8", { mandatory: ["shift"] }).to$(
      "yabai -m window --space 8 && yabai -m space --focus 8"
    ),
    map("9", { mandatory: ["shift"] }).to$(
      "yabai -m window --space 9 && yabai -m space --focus 9"
    ),
    map("c").to$(
      "yabai -m space --create"
    ),
    map("d").to$(
      "yabai -m space --destroy"
    ),
    map("m").to$(
      "yabai -m space --move next || yabai -m space --move prev"
    ),
    map("tab").to$(
      "yabai -m space --focus recent"
    ),
  ]),
];
