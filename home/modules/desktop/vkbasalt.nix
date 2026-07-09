# vkbasalt user config: the shader path for games on this box. the layer .so
# itself is installed at the SYSTEM layer (modules/nixos/gaming.nix); this file
# only renders vkBasalt.conf and pins the reshade fx shader set. WHY vkbasalt
# and not in-prefix reshade for everything: it sits on the host vulkan loader
# (under dxvk), outside the game's dll space, so it also covers pso2 ngs where
# gameguard makes injected dlls a gamble. ffxiv can ALSO run real reshade in
# the game dir (xivlauncher auto-detects it); the two coexist.
# opt-in per game: ENABLE_VKBASALT=1 in steam launch options / launcher env.
{ pkgs, ... }:
let
  # slim branch of the stock reshade fx collection (CAS, SMAA, LumaSharpen,
  # Vibrance, Clarity, FakeHDR...). pinned by rev so the shader set only moves
  # when deliberately bumped.
  reshade-shaders = pkgs.fetchFromGitHub {
    owner = "crosire";
    repo = "reshade-shaders";
    rev = "6db142b4b1a05c764222e5b0bd9a644b7ccfe1dc";
    hash = "sha256-WqT4eU8ZlGwKEgUEGlivz+35GprKX4goBeLnp9D5lTY=";
  };
in
{
  xdg.configFile."vkBasalt/vkBasalt.conf".text = ''
    # effects chain, applied in order. cas alone is near-free sharpening that
    # counters taa/upscale blur; append any name defined below to taste, e.g.
    # effects = cas:vibrance
    effects = cas

    casSharpness = 0.4

    # reshade fx wiring: paths for includes/textures, then each fx exposed as
    # a name usable in the chain. color-only shaders on purpose; vkbasalt has
    # no reshade depth-buffer access, so depth effects (mxao, dof) stay out.
    reshadeTexturePath = ${reshade-shaders}/Textures
    reshadeIncludePath = ${reshade-shaders}/Shaders
    lumaSharpen = ${reshade-shaders}/Shaders/LumaSharpen.fx
    vibrance = ${reshade-shaders}/Shaders/Vibrance.fx
    clarity = ${reshade-shaders}/Shaders/Clarity.fx
    fakeHDR = ${reshade-shaders}/Shaders/FakeHDR.fx
    tonemap = ${reshade-shaders}/Shaders/Tonemap.fx

    # Home toggles the chain in-game. the layer only wakes up at all when the
    # game was launched with ENABLE_VKBASALT=1, so this costs nothing globally.
    toggleKey = Home
    enableOnLaunch = True
  '';
}
