{ pkgs, callPackage }:

let
  # TODO specifying Black in buildInputs, propagatedBuildInputs, etc.
  # doesn't put it on the PATH. (I think I tried all of the options.)
  # More info: https://nixos.org/nixpkgs/manual/#ssec-stdenv-dependencies
  # See also: https://github.com/NixOS/nixpkgs/issues/26146
  #
  # But Black needs to be on the PATH to work with Neoformat.
  # Options:
  # 1. Have Black run "inside the Vim process directly", not via Neoformat/CLI.
  #    (See https://github.com/ambv/black#vim)
  #    The docs say it runs faster this way. But would that work with Nix? The
  #    docs also say, "On first run, the plugin creates its own virtualenv using
  #    the right Python version and automatically installs Black."
  # 2. Specify Black as a dependency in ../../common.nix
  #    For now, I'm using a hack by specifying custom.black in common.nix,
  #    but I should be able to specify all my Vim deps in here.
  # 3. Something else?
  vimCustomBuildInputs = import ./buildInputs.nix; 
  CUSTOM_PATH = builtins.unsafeDiscardStringContext ("\"" + builtins.concatStringsSep ":" (builtins.map (b: builtins.toString (b.outPath) + "/bin") vimCustomBuildInputs) + "\"");
  POWER_LINE_ROOT = builtins.unsafeDiscardStringContext ("\"" + pkgs.python36Packages.powerline.outPath + "\"");

  vim_configurable = pkgs.vim_configurable;

  vim_configured = vim_configurable.overrideAttrs (oldAttrs: {
    # NOTE: we don't need to specify the following:
    #   with import <nixpkgs> { config.vim.ftNix = false; };
    # because we specify the same thing here:
    ftNixSupport = false;
    buildInputs = vim_configurable.buildInputs ++ [
      ####################
      # Deps for powerline
      ####################
      # TODO does the powerline package automatically install the powerline fonts?
      #pkgs.powerline-fonts
      # NOTE: the PyPi name is powerline-status, but the Nix name is just powerline.
      pkgs.python36Packages.powerline
    ] ++ vimCustomBuildInputs;
  });

in

vim_configured.customize {
    name = "vim";
    vimrcConfig.customRC = builtins.replaceStrings ["CUSTOM_PATH_REPLACE_ME" "POWER_LINE_ROOT_REPLACE_ME"] [CUSTOM_PATH POWER_LINE_ROOT] (builtins.readFile ./.vimrc);

    # Use the default plugin list shipped with nixpkgs
    vimrcConfig.vam.knownPlugins = pkgs.vimPlugins;
    vimrcConfig.vam.pluginDictionaries = [
      { names = [
        # Here you can place all your vim plugins
        # They are installed managed by `vam` (a vim plugin manager)
        # Lookup names here:
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/misc/vim-plugins/default.nix
        # and here: http://vam.mawercer.de/

        # provides nix syntax highlighting, filetype detection and indentation.
        # NOTE: using vim-nix instead of this: { config.vim.ftNix = true; }
        "vim-nix"

        # This should more properly be named dracula or dracula-them-vim
        # https://draculatheme.com/vim/
        "vim"

        # make vim syntax aware
        "Syntastic"
        # syntax providers (see dependencies in vim_configured.buildInputs)
        "vim-javascript"
        "vim-jsdoc"
        "typescript-vim"

        # format code (see dependencies in vim_configured.buildInputs)
        "neoformat"

        # provides typescript autocomplete, error checking and more.
        "tsuquyomi"

        # autocomplete
        # TODO does this work? See https://nixos.wiki/wiki/Vim#YouCompleteMe
        "YouCompleteMe"

        # automatic closing of quotes, parenthesis, brackets, etc.
        # https://github.com/jiangmiao/auto-pairs
        "auto-pairs"

        # type "ysiw]" to surround w/ brackets
        "surround"

        # ctrlp makes it easier to open files, buffers, etc.
        # Call it with :CtrlPMixed or Ctrl+p
        "ctrlp"
        # This C extension speeds up ctrlp's finder
        "ctrlp-cmatcher"

        # git wrapper
        #   For screencasts on how to use:
        #     https://github.com/tpope/vim-fugitive#screencasts
        #   To compare a file across branches:
        #     Gedit master:myfile.txt
        #     Gdiff dev:myfile.txt
        "fugitive"

        # Handle delimited files (.csv, .tsv, etc.)
        #   http://vimawesome.com/plugin/csv-vim
        #   If a file is .txt, tell vim it's delimited with:
        #     :set filetype=csv
        "csv"
      ]; }
    ];
}