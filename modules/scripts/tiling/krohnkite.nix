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
    {
      value = "btree";
      label = "BTreeLayout";
    }
    {
      value = "monocle";
      label = "MonocleLayout";
    }
    {
      value = "column";
      label = "ColumnsLayout";
    }
    {
      value = "floating";
      label = "FloatingLayout";
    }
    {
      value = "quarter";
      label = "QuarterLayout";
    }
    {
      value = "spiral";
      label = "SpiralLayout";
    }
    {
      value = "threeColumn";
      label = "ThreeColumnLayout";
    }
    {
      value = "tile";
      label = "TileLayout";
    }
    {
      value = "stacked";
      label = "StackedLayout";
    }
    {
      value = "spread";
      label = "SpreadLayout";
    }
    {
      value = "stair";
      label = "StairLayout";
    }
  ];

  krohnkiteLayouts = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = with lib.types; enum (lib.lists.forEach krohnkiteSupportedLayouts (x: x.value));
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
          "enable${layout.label}" = isLayoutEnabled layout.value;
        }
        // (
          if isLayoutEnabled layout.value then
            lib.getAttrFromPath [ "options" ] (lib.findFirst (l: l.name == layout.value) layouts) // { }
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
        };
    };
  };
}
