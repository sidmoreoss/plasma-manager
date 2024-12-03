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
            description = "${name} gap for krohnkite.";
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
      name = lib.mkOption { type = with lib.types; nullOr (enum krohnkiteSupportedLayouts); };
    };
  };

  mkNullableOption =
    type: description: example:
    lib.mkOption {
      type = with lib.types; nullOr type;
      default = null;
      example = if type == lib.types.bool then true else null; # Example defaults for bool or other types
      description = description;
    };
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
          type = with lib.types; nullOr (ints.between 1 100);
          default = null;
          example = 1.6; # Example must match a valid float-like value
          description = "Tile width limiting ratio for Krohnkite.";
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
          ];
          description = "List of layout configurations for Krohnkite.";
        };
      };
    };
  };
  config = (
    lib.mkIf cfg.enable {
      home.packages =
        with pkgs;
        [ ] ++ lib.optionals (cfg.kwin.scripts.krohnkite.enable == true) [ kdePackages.krohnkite ];

      programs.plasma.configFile."kwinrc" = lib.mkIf (cfg.kwin.scripts.krohnkite.enable != null) {
        Plugins.krohnkiteEnabled = cfg.kwin.scripts.krohnkite.enable;
        Script-krohnkite = {
          screenGapTop = cfg.kwin.scripts.krohnkite.settings.geometry.gaps.top;
          screenGapLeft = cfg.kwin.scripts.krohnkite.settings.geometry.gaps.left;
          screenGapRight = cfg.kwin.scripts.krohnkite.settings.geometry.gaps.right;
          screenGapBottom = cfg.kwin.scripts.krohnkite.settings.geometry.gaps.bottom;
          tileLayoutGap = cfg.kwin.scripts.krohnkite.settings.geometry.gaps.tiles;
          limitTileWidth = cfg.kwin.scripts.krohnkite.settings.geometry.tileWidthLimit.enable;
          limitTileWidthRatio = cfg.kwin.scripts.krohnkite.settings.geometry.tileWidthLimit.ratio;
          enableBTreeLayout = cfg.kwin.scripts.krohnkite.settings.layouts.btree.enable;
          enableColumnsLayout = cfg.kwin.scripts.krohnkite.settings.layouts.columns.enable;
          columnsBalanced = cfg.kwin.scripts.krohnkite.settings.layouts.columns.balanced;
          enableFloatingLayout = cfg.kwin.scripts.krohnkite.settings.layouts.floating.enable;
          enableMonocleLayout = cfg.kwin.scripts.krohnkite.settings.layouts.monocle.enable;
          monocleMaximize = cfg.kwin.scripts.krohnkite.settings.layouts.monocle.maximize;
          enableQuarterLayout = cfg.kwin.scripts.krohnkite.settings.layouts.quarter.enable;
          enableSpiralLayout = cfg.kwin.scripts.krohnkite.settings.layouts.spiral.enable;
          enableSpreadLayout = cfg.kwin.scripts.krohnkite.settings.layouts.spread.enable;
          enableStackedLayout = cfg.kwin.scripts.krohnkite.settings.layouts.stacked.enable;
          enableStairLayout = cfg.kwin.scripts.krohnkite.settings.layouts.stair.enable;
          enableThreeColumnLayout = cfg.kwin.scripts.krohnkite.settings.layouts.threeColumn.enable;
          enableTileLayout = cfg.kwin.scripts.krohnkite.settings.layouts.tile.enable;
          layoutPerActivity = cfg.kwin.scripts.krohnkite.settings.layouts.enableLayoutPerActivity;
          layoutPerDesktop = cfg.kwin.scripts.krohnkite.settings.layouts.enableLayoutPerDesktop;
        };
      };
    }
  );
}
