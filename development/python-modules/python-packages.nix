{ callPackage }:

{
  arviz = callPackage ./arviz/default.nix {};
  daff = (callPackage ./daff/requirements.nix {}).packages.daff;
  flask-mwoauth = callPackage ./flask-mwoauth/default.nix {};
}
