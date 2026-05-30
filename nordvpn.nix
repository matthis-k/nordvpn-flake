{
  autoPatchelfHook,
  dpkg,
  fetchurl,
  lib,
  stdenv,
  sysctl,
  iptables,
  iproute2,
  procps,
  cacert,
  libxml2_13,
  sqlite,
  libidn2,
  zlib,
  wireguard-tools,
  icu72,
  libnl,
  libcap_ng,
}: let
  pname = "nordvpn";
  version = "5.0.0";

  nordvpn-amd64-deb = fetchurl {
    url = "https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/n/nordvpn/nordvpn_5.0.0_amd64.deb";
    hash = "sha256-F7/5WAAGaX3IJ3v/psp9cyWGs7kn2XOiCSN2Q6zeRAY=";
  };

  nordvpn-arm64-deb = fetchurl {
    url = "https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/n/nordvpn/nordvpn_5.0.0_arm64.deb";
    hash = lib.fakeHash;
  };

  nordVPNBase = stdenv.mkDerivation {
    inherit pname version;

    src =
      if stdenv.hostPlatform.system == "x86_64-linux"
      then nordvpn-amd64-deb
      else if stdenv.hostPlatform.system == "aarch64-linux"
      then nordvpn-arm64-deb
      else throw "Unsupported platform: ${stdenv.hostPlatform.system}";

    buildInputs = [libidn2 icu72 libnl libcap_ng sqlite libxml2_13];
    nativeBuildInputs = [dpkg autoPatchelfHook stdenv.cc.cc.lib];

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack
      dpkg --extract $src .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      mv usr/* $out/
      mv var/ $out/
      mv etc/ $out/
      runHook postInstall
    '';
  };

  nordVPNfhs = buildFHSEnvChroot {
    name = "nordvpnd";
    runScript = "${nordVPNBase}/bin/nordvpnd";

    targetPkgs = pkgs: [
      nordVPNBase
      sysctl
      iptables
      iproute2
      libxml2_13
      procps
      cacert
      libidn2
      zlib
      wireguard-tools
      icu72
      libnl
      libcap_ng
    ];
  };
in
  stdenv.mkDerivation {
    inherit pname version;

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/share
      ln -s ${nordVPNBase}/bin/nordvpn $out/bin
      ln -s ${nordVPNfhs}/bin/nordvpnd $out/bin
      ln -s ${nordVPNBase}/share/* $out/share/
      ln -s ${nordVPNBase}/var $out/
      runHook postInstall
    '';

    meta = with lib; {
      description = "CLI client for NordVPN";
      homepage = "https://www.nordvpn.com";
      license = licenses.unfreeRedistributable;
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  }
