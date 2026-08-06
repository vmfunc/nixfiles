# the full KDE Gear application catalog (rice.kdeApps.*), default OFF, switched
# on per host. exists for the plasma tablet posture (rice.tablet.plasmaSession):
# the session ships nearly appless by default, and on a couch convertible the
# whole catalog (games and edu included) is the point, not bloat. everything is
# binary-cached, so the cost is closure size (a few GiB), not build time.
# the roster was eval-verified against the pinned nixpkgs: most apps live under
# kdePackages (the qt6 gear set), a handful only exist top-level. konsole comes
# with the plasma6 session itself (riced in home/modules/terminal/konsole.nix)
# and kdeconnect has its own module (rice.kdeconnect), so neither repeats here.
#
# dropped as broken in the current nixpkgs pin, re-add when they build again:
# kdePackages.neochat, kdePackages.itinerary, knotes, calligra.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.kdeApps;
in
{
  options.rice.kdeApps.enable = lib.mkEnableOption "the full KDE Gear application catalog";

  config = lib.mkIf cfg.enable {
    # the akonadi-backed pim stack through the real module, not bare packages:
    # it wires akonadi + kdepim-addons so mail/calendar actually have backends.
    programs.kde-pim = {
      enable = true;
      kmail = true;
      kontact = true;
      merkuro = true;
    };

    environment.systemPackages =
      (with pkgs.kdePackages; [
        # files / system
        dolphin
        ark
        filelight
        kdf
        partitionmanager
        ksystemlog
        yakuake
        kwalletmanager
        kfind
        kbackup
        sweeper
        isoimagewriter
        # utilities
        kate
        kcalc
        kcharselect
        kclock
        kweather
        kalarm
        ktimer
        kteatime
        keysmith
        skanpage
        kcolorchooser
        kruler
        kmag
        kmousetool
        kmouth
        francis
        qrca
        telly-skout
        # graphics / reading
        gwenview
        okular
        kolourpaint
        kgraphviewer
        koko
        arianna
        # multimedia
        elisa
        kdenlive
        kwave
        kamoso
        kasts
        audiotube
        plasmatube
        k3b
        dragon
        juk
        kmix
        krecorder
        audex
        # internet
        falkon
        angelfish
        konversation
        tokodon
        krdc
        krfb
        ktorrent
        kget
        akregator
        alligator
        kongress
        kio-extras
        # pim / writing (the kde-pim module above carries kmail/kontact/merkuro)
        korganizer
        kaddressbook
        zanshin
        marknote
        ghostwriter
        kjournald
        # dev
        kompare
        kcachegrind
        lokalize
        massif-visualizer
        kdevelop
        umbrello
        # education
        marble
        kgeography
        kalzium
        kanagram
        khangman
        ktouch
        kwordquiz
        minuet
        kiten
        klettres
        kbruch
        kalgebra
        cantor
        kig
        kmplot
        step
        artikulate
        parley
        blinken
        kturtle
        # games
        kpat
        kmines
        ksudoku
        kmahjongg
        knights
        kblocks
        kbounce
        kbreakout
        katomic
        kapman
        kgoldrunner
        kigo
        killbots
        kiriki
        kjumpingcube
        klickety
        klines
        knavalbattle
        knetwalk
        kolf
        kollision
        konquest
        kreversi
        kshisen
        ksirk
        ksnakeduel
        kspaceduel
        ksquares
        ktuberling
        kubrick
        lskat
        granatier
        bomber
        bovo
        picmi
        palapeli
        kdiamond
        kfourinline
        kblackbox
      ])
      # kde apps that only exist top-level in nixpkgs (qt6 builds outside the set)
      ++ (with pkgs; [
        krusader
        kphotoalbum
        haruna
        okteta
        kstars
        labplot
        digikam
        krita
        gcompris
        kdiff3
        krename
        kile
      ]);
  };
}
