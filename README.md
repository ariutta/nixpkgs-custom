# Cheatsheet for creating custom packages

First check [nixpkgs](https://search.nixos.org/packages) and [Nix User Repositories](https://nur.nix-community.org/) to see whether the package has already been created. If not, create a custom package yourself.

## poetry2nix

```
nix-shell poetry-shell.nix
poetry add --lock jupytext jupyterlab
poetry lock && nix-shell test.nix --show-trace
```

## Test a package expression

### Via `nix-build`

```sh
cd ./abc_dir
nix-build -E 'with import <nixpkgs> { }; callPackage ./default.nix {}' -K
./result/bin/abc --help
rm result
```

For example:

```
cd pathvisio
nix-build -E 'with import <nixpkgs> {}; let java-buildpack-memory-calculator = callPackage ../java-buildpack-memory-calculator/default.nix {}; in callPackage ./default.nix { inherit java-buildpack-memory-calculator; }' -K
./result/bin/abc --help
rm result
```

### Via `nix repl`:

```
nix repl '<nixpkgs>'
pkgs = import <nixpkgs> { overlays=[(import ./overlay.nix)]; }
:b pkgs.python3Packages.callPackage ./nixpkgs/jupyter_server/default.nix {}
```

or alternatively:

```
nix repl '<nixpkgs>'
overlays = [(import ./overlay.nix)]
pkgs = import <nixpkgs> { inherit overlays; }
:b pkgs.python3Packages.callPackage ./nixpkgs/jupyter_server/default.nix {}
```

## Python

Generate Nix expressions for python packages by using pypi2nix, if possible. Otherwise, create manually.
In the future, consider adding the manually-created packages to [python-packages.nix](https://github.com/NixOS/nixpkgs/blob/master/pkgs/top-level/python-packages.nix) and make a pull request.

### Applications

For python packages used as stand-alone applications (even if also used as dependencies):

```sh
mkdir -p tosheets
cd tosheets
pypi2nix -V 3 -e tosheets==0.3.0
```

Then add the package to `./all-custom.nix`.

### Dependency-Only

For packages used only as dependencies (never as stand-alone applications):

```sh
mkdir -p ./development/python-modules/homoglyphs
cd ./development/python-modules/homoglyphs
pypi2nix -V 3 -e homoglyphs==1.2.5
```

Then add the package to `./development/python-modules/python-packages.nix`.

## [Ruby](https://nixos.org/nixpkgs/manual/#sec-language-ruby)

Get or create a Gemfile for the package. Then follow the manual's instructions to run bundix and create a default.nix file. Put the following files under version control:

- default.nix
- Gemfile
- Gemfile.lock
- gemset.nix

## Re-using

Long-term, some of these packages may be included in Nix packages. But for the packages not yet included,
you can use a subtree to pull them into your own project:

Setup the `mynixpkgs` subtree, if not done already:

```
git remote add mynixpkgs git@github.com:ariutta/mynixpkgs.git
git subtree add --prefix mynixpkgs mynixpkgs master --squash
```

Sync subtree repo:

```
git subtree pull --prefix mynixpkgs mynixpkgs master --squash
git subtree push --prefix mynixpkgs mynixpkgs master
```
