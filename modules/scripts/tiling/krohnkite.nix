{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.plasma;

  krohnkiteGaps = lib.types.submodule {
    options =
      let
        mkGapOption =
          name:
          lib.mkOption {
            type = with lib.types; nullOr (ints.between 0 999);
            default = null;
            example = 8;
            description = "${name} gap for Krohnkite.";
          };
      in
      {
        top = mkGapOption "Top screen";
        left = mkGapOption "Left screen";
        right = mkGapOption "Right screen";
        bottom = mkGapOption "Bottom screen";
        tiles = mkGapOption "Gap between tiles";
      };
  };

  krohnkiteSupportedLayouts = [
    "btree"
    "monocle"
    "column"
    "floating"
    "quarter"
    "spiral"
    "threeColumn"
    "tile"
    "stacked"
    "spread"
    "stair"
  ];

  krohnkiteLayouts = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = with lib.types; enum krohnkiteSupportedLayouts;
        description = "The name of the layout.";
      };

      options = lib.mkOption {
        type = with lib.types; attrsOf (with lib.types; anything);
        default = { };
        example = {
          maximize = true;
        };
        description = ''
          Layout-specific options. For example:
          - `monocle` can have `{ maximize = true; }`
          - `column` can have `{ balanced = true; }`
        '';
      };
    };
  };

  mkNullableOption =
    type: description: example:
    lib.mkOption {
      type = with lib.types; nullOr type;
      default = null;
      example = example;
      description = description;
    };

  findLayoutSetting =
    name: key:
    let
      layout = lib.findFirst (
        layout: layout.name == name
      ) cfg.kwin.scripts.krohnkite.settings.layouts.enabled;
    in
    lib.getAttrFromPath [
      "options"
      key
    ] layout
    // null;

  isLayoutEnabled =
    name: lib.any (layout: layout.name == name) cfg.kwin.scripts.krohnkite.settings.layouts.enabled;

  serializeLayouts =
    layouts:
    let
      toLayoutEntry =
        layout:
        {
          "enable${lib.capitalize layout}" = isLayoutEnabled layout;
        }
        // (
          if isLayoutEnabled layout then
            lib.getAttrFromPath [ "options" ] (lib.findFirst (l: l.name == layout) layouts) // { }
          else
            { }
        );
    in
    lib.foldl' lib.recursiveUpdate { } (lib.map toLayoutEntry krohnkiteSupportedLayouts);
in
{
  options.programs.plasma.kwin.scripts.krohnkite = with lib.types; {
    enable = mkNullableOption bool "Whether to enable Krohnkite." true;

    settings = {
      gaps =
        mkNullableOption krohnkiteGaps
          "Gaps configuration for Krohnkite, e.g., top, bottom, left, right, and tiles."
          {
            top = 8;
            bottom = 8;
            left = 8;
            right = 8;
            tiles = 8;
          };

      tileWidthLimit = {
        enable = mkNullableOption bool "Whether to limit tile width for Krohnkite." true;

        ratio = lib.mkOption {
          type = with lib.types; nullOr (numbers.between 0 99);
          default = null;
          example = 1.6;
          description = "Tile width limiting ratio for Krohnkite. Must be a float between 0 and 99.";
        };
      };

      layouts = {
        enabled = lib.mkOption {
          type = with lib.types; listOf krohnkiteLayouts;
          default = [ ];
          example = [
            {
              name = "monocle";
              options = {
                maximize = true;
              };
            }
            {
              name = "column";
              options = {
                balanced = true;
              };
            }
          ];
          description = "List of layout configurations for Krohnkite.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      lib.optionals (cfg.kwin.scripts.krohnkite.enable != null) [ kdePackages.krohnkite ];

    programs.plasma.configFile."kwinrc" = lib.mkIf (cfg.kwin.scripts.krohnkite.enable != null) {
      Plugins.krohnkiteEnabled = cfg.kwin.scripts.krohnkite.enable;
      Script-krohnkite =
        let
          gaps = cfg.kwin.scripts.krohnkite.settings.gaps;
        in
        serializeLayouts cfg.kwin.scripts.krohnkite.settings.layouts.enabled
        // {
          screenGapTop = gaps.top;
          screenGapLeft = gaps.left;
          screenGapRight = gaps.right;
          screenGapBottom = gaps.bottom;
          tileLayoutGap = gaps.tiles;

          limitTileWidth = cfg.kwin.scripts.krohnkite.settings.tileWidthLimit.enable;
          limitTileWidthRatio = cfg.kwin.scripts.krohnkite.settings.tileWidthLimit.ratio;

          layoutPerActivity = cfg.kwin.scripts.krohnkite.settings.layouts.layoutPerActivity;
          layoutPerDesktop = cfg.kwin.scripts.krohnkite.settings.layouts.layoutPerDesktop;
        };
    };
  };
}
