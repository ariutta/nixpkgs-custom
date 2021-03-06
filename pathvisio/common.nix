{ ant
, bc
, callPackage
, coreutils
, fetchFromGitHub
, fetchurl
, getopt
, imagemagick7
, jdk8
, jre8
, makeDesktopItem
, parallel
, stdenv
, lib
, unzip
, xmlstarlet
, poppler_utils # for pdftocairo
, memory
, java-buildpack-memory-calculator
, headless ? false
, organism ? "Homo sapiens"
, datasources ? [] }:
# TODO: allow for specifying plugins to install
#       How? I don't think we can symlink into
#       the user's $HOME/.PathVisio dir during
#       build/installation. Also, we don't want
#       to mess up PathVisio's own plugin manager.

with builtins;

let
  baseName = "PathVisio";
  version = "3.3.0";
  sensible-jvm-opts = callPackage ./sensible-jvm-opts.nix {
    inherit lib stdenv coreutils fetchurl java-buildpack-memory-calculator;
  }; 
in
stdenv.mkDerivation rec {
  name = replaceStrings [" "] ["_"] (concatStringsSep "-" (filter (x: isString x) [baseName version organism]));

  # nativeBuildInputs shouldn't persist as run-time dependencies.
  #   From the manual:
  #   "Since these packages are able to be run at build time, that are added to
  #    the PATH, as described above. But since these packages only are
  #    guaranteed to be able to run then, they shouldn't persist as run-time
  #    dependencies. This isn't currently enforced, but could be in the future."
  nativeBuildInputs = [ ant bc imagemagick7 jdk8 parallel poppler_utils sensible-jvm-opts unzip ];

  # buildInputs may be used at run-time but are only on the PATH at build-time.
  #   From the manual:
  #   "These often are programs/libraries used by the new derivation at
  #    run-time, but that isn't always the case."
  #buildInputs = [ ];

  # I think propagatedBuildInputs may stay on the path at run-time.
  propagatedBuildInputs = [ coreutils getopt jre8 xmlstarlet ] ++ map (d: d.src) datasources;

  bridgedbSettings = fetchurl {
    url = "http://repository.pathvisio.org/plugins/pvplugins-bridgedbSettings/1.0.0/pvplugins-bridgedbSettings-1.0.0.jar";
    sha256 = "0gq5ybdv4ci5k01vr80ixlji463l9mdqmkjvhb753dbxhhcnxzjy";
  };

  pathvisioPluginsXML = ./pathvisio.xml;
  pathwayStub = ./pathway.gpml;
  PHASHSUMS = ./PHASHSUMS;
  SHA256SUMS = ./SHA256SUMS;
  # To reset sums, run the following:
  #     cd ./pathvisio
  #     nix-build -E 'with import <nixpkgs> {}; let java-buildpack-memory-calculator = callPackage ../java-buildpack-memory-calculator/default.nix {}; in callPackage ./default.nix { inherit java-buildpack-memory-calculator; }' -K
  #
  #     The output will be in a <testResultsDir>, e.g., ${src}/test-results
  #     Manually verify the output(s) in <testResultsDir> that failed.
  #
  #     If you don't remember which failed, you can diff as shown below,
  #     but this method is really only useful for SHA256SUMS.
  #     PHASHSUMS change slightly even when things are OK.
  #     diff ./PHASHSUMS <testResultsDir>/PHASHSUMS
  #     diff ./SHA256SUMS <testResultsDir>/SHA256SUMS
  #
  #     If the new outputs look OK, copy over the new sums:
  #     cp <testResultsDir>/PHASHSUMS ./PHASHSUMS
  #     cp <testResultsDir>/SHA256SUMS ./SHA256SUMS

  XSLT_NORMALIZE = ./normalize.xslt;
  WP4321_98000_BASE64 = fetchurl {
    name = "WP4321_98000.gpml.base64";
    url = "http://webservice.wikipathways.org/getPathwayAs?fileType=gpml&pwId=WP4321&revision=98000";
    sha256 = "0hxd03ni5ws6n219bz5wrs0lv0clk0qnrigz3qwrqbna54vi3n6m";
  };
  WP4321_98055_BASE64 = fetchurl {
    name = "WP4321_98055.gpml.base64";
    url = "http://webservice.wikipathways.org/getPathwayAs?fileType=gpml&pwId=WP4321&revision=98055";
    sha256 = "0d4r54hkl4fcvl85s7c1q844rbjwlg99x66l7hhr00ppb5xr17v0";
  };

  libPathSrc = "/build/source/lib";
  libPathOut = "$out/lib/pathvisio";

  modulesPathSrc = "/build/source/modules";
  modulesPathOut = "${libPathOut}/modules";

  sharePathOut = "$out/share/pathvisio";

  tmpBuildDir = "/build";

  binPathTmp = "/build/bin";
  binPathOut="$out/bin";

  logDir = "/build/logs";
  testResultsDir="/build/testResults";

  biopax3GPMLSrc = fetchurl {
    url = "https://github.com/wikipathways/wikipathways.org/blob/e8fae01eae010e498d7408ca38e0beda1e8625d7/wpi/bin/Biopax3GPML.jar?raw=true";
    sha256 = "1jm5khh6n78fghd7wp0m5dcb6s2zp23pgsbw56rpajfxgx1sz7lg";
  };

  converterClasses = [
    "${modulesPathSrc}/org.pathvisio.core.jar"
    "${libPathSrc}/com.springsource.org.jdom-1.1.0.jar"
    "${libPathSrc}/org.bridgedb.jar"
    "${libPathSrc}/org.bridgedb.bio.jar"
    "${libPathSrc}/org.apache.batik.bridge_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.css_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.dom_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.dom.svg_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.ext.awt_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.extension_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.parser_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.svggen_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.transcoder_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.util_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.util.gui_1.7.0.v200903091627.jar"
    "${libPathSrc}/org.apache.batik.xml_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.pathvisio.pdftranscoder.jar"
    "${libPathSrc}/org.w3c.css.sac_1.3.1.v200903091627.jar"
    "${libPathSrc}/org.w3c.dom.events_3.0.0.draft20060413_v201105210656.jar"
    "${libPathSrc}/org.w3c.dom.smil_1.0.1.v200903091627.jar"
    "${libPathSrc}/org.w3c.dom.svg_1.1.0.v201011041433.jar"
    biopax3GPMLSrc
  ];
  differClasses = [
    "${modulesPathSrc}/org.pathvisio.core.jar"
    "${libPathSrc}/com.springsource.org.jdom-1.1.0.jar"
    "${libPathSrc}/org.bridgedb.jar"
    "${libPathSrc}/org.bridgedb.bio.jar"
  ];
  patcherClasses = [
    "${modulesPathSrc}/org.pathvisio.core.jar"
    "${libPathSrc}/com.springsource.org.jdom-1.1.0.jar"
    "${libPathSrc}/org.bridgedb.jar"
    "${libPathSrc}/org.bridgedb.bio.jar"
  ];

  # TODO: gui launcher classes vs. jar?
  guiClasses = [
    "${modulesPathSrc}/org.pathvisio.core.jar"
    "${modulesPathSrc}/org.pathvisio.launcher.jar"
    "${libPathSrc}/com.springsource.org.jdom-1.1.0.jar"
    "${libPathSrc}/org.bridgedb.jar"
    "${libPathSrc}/org.bridgedb.bio.jar"
    "${libPathSrc}/org.apache.batik.bridge_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.css_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.dom_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.dom.svg_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.ext.awt_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.extension_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.parser_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.svggen_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.transcoder_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.util_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.apache.batik.util.gui_1.7.0.v200903091627.jar"
    "${libPathSrc}/org.apache.batik.xml_1.7.0.v201011041433.jar"
    "${libPathSrc}/org.pathvisio.pdftranscoder.jar"
    "${libPathSrc}/org.w3c.css.sac_1.3.1.v200903091627.jar"
    "${libPathSrc}/org.w3c.dom.events_3.0.0.draft20060413_v201105210656.jar"
    "${libPathSrc}/org.w3c.dom.smil_1.0.1.v200903091627.jar"
    "${libPathSrc}/org.w3c.dom.svg_1.1.0.v201011041433.jar"
    biopax3GPMLSrc
  ];

  converterCLASSPATH = concatStringsSep ":" (converterClasses);
  differCLASSPATH = concatStringsSep ":" (differClasses);
  patcherCLASSPATH = concatStringsSep ":" (patcherClasses);

  guiCLASSPATH = concatStringsSep ":" (guiClasses);

  src = fetchFromGitHub {
    owner = "PathVisio";
    repo = "pathvisio";

    # v3.3.0
    rev = "61f15de96b676ee581858f0485f9c6d8f61a3476";
    sha256 = "1n2897290g6kph1l04d2lj6n7137w0gnavzp9rjz43hi1ggyw6f9";

    # v3.4.0
    #rev = "d93a7aad72f66a1a2a3eaec3f91667853e5c8861";
    #sha256 = "0xw7zxk69vlazjhc0p0jqzyqx9nh27prvdmki2k383zpg38ac5n7";
  };

  pngIconSrc = "${src}/www/bigcateye_135x135.png";

  iconSrc = "${src}/lib-build/bigcateye.icns";

  # We're using Java 8, and these items should match that.
  patchPhase = ''
    substituteInPlace build-common.xml \
      --replace 'name="ant.build.javac.target" value="1.6"' 'name="ant.build.javac.target" value="1.8"' \
      --replace 'name="ant.build.javac.source" value="1.6"' 'name="ant.build.javac.source" value="1.8"'
  '';

  buildPhase = (if headless then ''
    ant
  '' else if stdenv.system == "x86_64-darwin" then ''
    ant appbundler
  '' else ''
    ant exe
  '') + ''
    mkdir -p "${binPathTmp}"
    mkdir -p "${logDir}"

    # NOTE: we need to cd into the bin directory here, because the CLASSPATHs
    #       are relative to the bin directory.
    cd "${binPathTmp}"
    converter_java_opts=$(sensible-jvm-opts "${converterCLASSPATH}" "${memory}")
    differ_java_opts=$(sensible-jvm-opts "${differCLASSPATH}" "${memory}")
    gui_java_opts=$(sensible-jvm-opts "${guiCLASSPATH}" "${memory}")
    patcher_java_opts=$(sensible-jvm-opts "${patcherCLASSPATH}" "${memory}")

    cd "${tmpBuildDir}"

    #####################################################
    # The following creates a file that serves as the CLI
    #####################################################
    cat > ${binPathTmp}/pathvisio <<EOF
#! $shell
TOP_OPTS=\$("getopt" -o hvX: --long help,version:,icon: \
             -n 'pathvisio' -- "\$@")

if [ \$? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# NOTE: keep the quotes
eval set -- "\$TOP_OPTS"

HELP=false
VERSION=false
JAVA_CUSTOM_OPTS_ARR=()
ICON=
while true; do
  case "\$1" in
    -h | --help ) HELP=true; shift ;;
    -v | --version ) VERSION=true; shift ;;
    -X ) JAVA_CUSTOM_OPTS_ARR+=("-X\$2"); shift 2 ;;
    --icon ) ICON="\$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

SUBCOMMAND=""
if [[ "\$1" =~ ^(convert|diff|patch|launch)$ ]]; then
  SUBCOMMAND="\$1"
  shift
elif [[ -z "\$1" ]]; then
  SUBCOMMAND=false
else
  echo "Invalid subcommand \$1" >&2
  exit 1
fi

# NOTE: if a user passes in custom JVM options, the sensible options are not used.
JAVA_CUSTOM_OPTS=\$(IFS=" " ; echo "\$'' + ''{JAVA_CUSTOM_OPTS_ARR[*]}")

if [ \$VERSION == true ]; then
  java -jar -Dfile.encoding=UTF-8 ${sharePathOut}/pathvisio.jar -v
  exit 0
elif [ \$SUBCOMMAND == false ] && [ \$HELP == true ]; then
  echo 'usage: pathvisio [--version] [--help] [<command> <args>]'
  echo 'commands: convert, diff, patch, launch'
  exit 0
elif [ \$SUBCOMMAND = 'convert' ]; then
  if [ \$HELP == true ]; then
    echo 'usage: pathvisio convert <input> <output> [<scale>]'
    echo '       scale is only for converting to PNG format.'
    echo ' '
    echo 'examples on example data WP1243_69897.gpml:'
    echo '    wget https://github.com/PathVisio/GPML/blob/fa76a73db631bdffcf0f63151b752e0e0357fd26/test/2013a/WP1243_69897.gpml?raw=true -O WP1243_69897.gpml'
    echo ' '
    echo '  # GPML -> BioPAX/OWL'
    echo '  pathvisio convert WP1243_69897.gpml WP1243_69897.owl'
    echo '  # GPML -> PDF'
    echo '  pathvisio convert WP1243_69897.gpml WP1243_69897.pdf'
    echo '  # GPML -> PNG'
    echo '  pathvisio convert WP1243_69897.gpml WP1243_69897.png'
    echo '  # GPML -> PNG at 200% scale'
    echo '  pathvisio convert WP1243_69897.gpml WP1243_69897.png 200'
    exit 0
  fi

  # LocalSettings.php sets $wgMaxShellMemory:
  # https://github.com/wikipathways/wikipathways.org/blob/f6e9c337c0a9029f0f329dc1ab156858b1433406/LocalSettings.php#L27
  #
  # $wgMaxShellMemory = 512 * 1024;

  # pathvisio convert command called like this in Pathway.php:
  # https://github.com/wikipathways/wikipathways.org/blob/f6e9c337c0a9029f0f329dc1ab156858b1433406/wpi/extensions/Pathways/Pathway.php#L1243
  #
  # $maxMemoryM = intval($wgMaxShellMemory / 1024); //Max script memory on java program in megabytes
  # java -Xmx{$maxMemoryM}M -jar $basePath/bin/pathvisio_core.jar \"$gpmlFile\" \"$outFile\" 2>&1"

  CLASSPATH="${converterCLASSPATH}"
  java $'' + ''{JAVA_CUSTOM_OPTS:-$converter_java_opts} -ea -classpath \$CLASSPATH org.pathvisio.core.util.Converter "\$@"
  exit 0
elif [ \$SUBCOMMAND = 'diff' ]; then
  if [ \$HELP == true ]; then
    echo 'usage: pathvisio diff <input1> <input2>'
    echo ' '
    echo 'example (get data as described in pathvisio convert -h):'
    echo "  sed 's/Color=\\".*\\"/Color=\\"ff0000\\"/g' WP1243_69897.gpml > test.gpml"
    echo ' '
    echo '  pathvisio diff WP1243_69897.gpml test.gpml > test.patch'
    exit 0
  fi

  CLASSPATH="${differCLASSPATH}"
  java $'' + ''{JAVA_CUSTOM_OPTS:-$differ_java_opts} -ea -classpath \$CLASSPATH org.pathvisio.core.gpmldiff.GpmlDiff "\$@"
  exit 0
elif [ \$SUBCOMMAND = 'patch' ]; then
  if [ \$HELP == true ]; then
    echo 'usage: pathvisio patch <reference> < <patch>'
    echo ' '
    echo 'example (create patch file as described in pathvisio diff -h)'
    echo ' '
    echo '  pathvisio patch WP1243_69897.gpml < test.patch'
    exit 0
  fi

  CLASSPATH="${patcherCLASSPATH}"
  java $'' + ''{JAVA_CUSTOM_OPTS:-$patcher_java_opts} -ea -classpath \$CLASSPATH org.pathvisio.core.gpmldiff.PatchMain "\$@"
  exit 0
elif [ \$SUBCOMMAND = 'launch' ]; then
  # TODO: close this issue:
  # https://github.com/PathVisio/pathvisio/issues/97
  if [ \$HELP == true ];
  then
    java -jar -Dfile.encoding=UTF-8 ${sharePathOut}/pathvisio.jar -h | sed 's/pathvisio/pathvisio launch/'
    exit 0
  fi

  mkdir -p "\$HOME/.PathVisio/.bundles"
  PREFS_FILE="\$HOME/.PathVisio/.PathVisio"
  if [ ! -e "\$PREFS_FILE" ];
  then
    echo "#" >"\$PREFS_FILE";
    echo "#Wed Jun 27 16:21:04 PDT 2018" >>"\$PREFS_FILE";
  fi

  # Ensure we're connected to BridgeDb REST webservice
  if [ ! -e "\$HOME/.PathVisio/.bundles/pvplugins-bridgedbSettings-1.0.0.jar" ];
  then
    ln -s "${bridgedbSettings}" "\$HOME/.PathVisio/.bundles/pvplugins-bridgedbSettings-1.0.0.jar"

    cat ${pathvisioPluginsXML} | \
      xmlstarlet ed \
        -u '/ns2:pvRepository/url' \
        -v "\$HOME/.PathVisio/.bundles" | \
      xmlstarlet ed \
        -u '/ns2:pvRepository/bundle_version_list/pv_bundle_version/jar_file_url' \
        -v "\$HOME/.PathVisio/.bundles/pvplugins-bridgedbSettings-1.0.0.jar" \
      >"\$HOME/.PathVisio/.bundles/pathvisio.xml"
  fi

  '' + concatStringsSep "" (map (d: d.linkCmd) datasources) + ''

  target_file_raw=\$(echo "\$@" | sed "s#.*\\ \\([^\\ ]*\\.gpml\\(\\.xml\\)\\{0,1\\}\\)#\\1#")

  if [ ! "\$target_file_raw" ];
  then
    # We don't want to overwrite an existing file.
    suffix=\$(date +%s)
    target_dir="."
    if [ ! -w "\$target_dir/" ]; then
      target_dir="\$HOME"
    fi
    target_file_raw="\$target_dir/pathway-\$suffix.gpml"
  fi

  target_file=\$("${coreutils}/bin/readlink" -f "\$target_file_raw")

  patchedFlags=""

  # If no target file specified, or if it is specified but doesn't exist,
  # we create a starter file and open that.
  if [ ! -e "\$target_file" ];
  then
          echo "Opening new file: \$target_file" 1>&2
          xmlstarlet ed -N gpml='http://pathvisio.org/GPML/2013a' -u '/gpml:Pathway/@Organism' -v '${organism}' "${pathwayStub}" >"\$target_file"
          # TODO: verify the code above, replacing sed w/ xmlstarlet, works correctly.
#          cat "${pathwayStub}" >"\$target_file"
#          chmod u+rw "\$target_file"
#          sed -i.bak "s#Homo sapiens#${organism}#" "\$target_file"
#          rm "\$target_file.bak"
          patchedFlags="\$@ \$target_file"
  else
          echo "Opening specified file: \$target_file" 1>&2
          patchedFlags=\$(echo "\$@" | sed "s#\$target_file_raw#\$target_file#")
  fi

  # TODO how should we handle the case of opening a GPML file having
  # a species not matching organism specified above?

  current_organism="${organism}"
  if ! grep -Fq "${organism}" \$target_file;
  then
    current_organism=\$(xmlstarlet sel -N gpml='http://pathvisio.org/GPML/2013a' -t -v '/gpml:Pathway/@Organism'  "\$target_file")
    # TODO: verify the code above, replacing sed w/ xmlstarlet,  works correctly
    #current_organism=\$(grep -o 'Organism="\\(.*\\)"' \$target_file | sed 's#.*"\\(.*\\)".*#\\1#')
  fi

  # TODO verify that if a local gene or metabolite db is specified, it's used
  # even if we have the webservice running for the other.
  if ! grep -q "^BRIDGEDB_CONNECTION.*\$current_organism" "\$PREFS_FILE";
  then
    echo "Setting BRIDGEDB_CONNECTION_1 for \$current_organism" 1>&2
    sed -i.bak "/^BRIDGEDB_CONNECTION_.*$/d" "\$PREFS_FILE"
    rm "\$PREFS_FILE.bak"
    echo "BRIDGEDB_CONNECTION_1=idmapper-bridgerest\\:http\\://webservice.bridgedb.org\\:80/\$current_organism" >>"\$PREFS_FILE"
  fi
  # TODO: take a look at this:
  # https://github.com/tofi86/universalJavaApplicationStub

  # TODO: there are probably other settings/options from Info.plist
  #   https://github.com/PathVisio/pathvisio/blob/master/Info.plist
  #   that should be used for Darwin. Should we modify JavaApplicationStub
  #   to work with this pathvisio script, or should we move content from
  #   Info.plist into here?

  # NOTE: this enables drag & drop to the dock icon
  export CFProcessPath="$0"

  # NOTE: the -Xdock flags are not recognize on NixOS and cause an error.
  #       Probably only used on macOS?

  # NOTE: using nohup ... & to keep GUI running, even if the terminal is closed
  nohup java $'' + ''{JAVA_CUSTOM_OPTS:-$gui_java_opts} \
'' + (
if stdenv.system == "x86_64-darwin" then ''
    -Xdock:icon="${iconSrc}" \
    -Xdock:name="${name}" \
'' else ''
'' ) + ''
    -jar "${sharePathOut}/pathvisio.jar" \$patchedFlags >>"\$HOME/.PathVisio/PathVisio.log" 2>>"\$HOME/.PathVisio/PathVisio.log" &
else
  echo "Invalid subcommand \$1" >&2
  exit 1
fi
EOF
    chmod a+x "${binPathTmp}/pathvisio"
  '';

  doCheck = true;

  checkPhase = ''
    # TODO: Should we be running existing tests like the following here?
    # https://github.com/PathVisio/pathvisio/tree/master/modules/org.pathvisio.core/test/org/pathvisio/core

    mkdir -p "${testResultsDir}"

    cd "${binPathTmp}"

function gpml2many()
{
  local f=$1

  cp "$f" "${testResultsDir}/"

  converted_f="${testResultsDir}/"$(basename "$f" ".gpml")

  # convert/update from old GPML schema to latest:
  ./pathvisio convert "$f" "$converted_f".gpml >>"${logDir}/message.log" 2>>"${logDir}/error.log"
  xmlstarlet tr ${XSLT_NORMALIZE} "$converted_f".gpml >"$converted_f".norm.gpml

  ./pathvisio convert "$converted_f".gpml "$converted_f".owl >>"${logDir}/message.log" 2>>"${logDir}/error.log"
  xmlstarlet tr ${XSLT_NORMALIZE} "$converted_f".owl >"$converted_f".norm.owl
  cp "$converted_f".bpss "$converted_f".norm.bpss

  # TODO why does the sha256sum for converted PNGs differ between Linux and Darwin?
  ./pathvisio convert "$converted_f".gpml "$converted_f".png >>"${logDir}/message.log" 2>>"${logDir}/error.log"
  ./pathvisio convert "$converted_f".gpml "$converted_f"-200.png 200 >>"${logDir}/message.log" 2>>"${logDir}/error.log"
  ./pathvisio convert "$converted_f".gpml "$converted_f".pdf >>"${logDir}/message.log" 2>>"${logDir}/error.log"
}
export -f gpml2many

    echo "  performing all conversions: gpml->owl+bpss,png,png200,pdf (takes awhile)..." 1>&2

    processor_count=$(nproc)
    ls -1 "/build/source/"{example-data/,testData/,testData/2010a/{biopax,parsetest}}*.gpml | \
      parallel --eta -k -P $processor_count gpml2many {} >>"${logDir}/message.log" 2>>"${logDir}/error.log"

#    # Leaving this here in case I want to use it again later for debugging.
#    # It does the same as the parallel code above, just not in parallel.
#    for f in "/build/source/"{example-data/,testData/,testData/2010a/{biopax,parsetest}}*.gpml; do
#      echo "f: $f"
#      ls -lah "$f"
#      echo "    $(basename $f)" 1>&2
#      gpml2many "$f"
#    done

    cd "${testResultsDir}"

    PASSING=true

    if [ -n "$(cat ${SHA256SUMS})" ]; then
      echo '  verifying shasums...' 1>&2
      cp ${SHA256SUMS} "${testResultsDir}/SHA256SUMS"
      sha256sum -c --quiet "./SHA256SUMS"
    else
      PASSING=false
      echo ' '
      echo 'SHA256SUMS not set.' 1>&2
      echo "Verify the converted outputs in ${testResultsDir}" 1>&2
      echo "If they look OK, get the updated SHA256SUMS:" 1>&2
      echo "cp ${testResultsDir}/SHA256SUMS ./SHA256SUMS" 1>&2
      echo ' ' 1>&2
      touch "${testResultsDir}/SHA256SUMS"
      sha256sum --tag ./*.norm.{bpss,gpml,owl} >>"${testResultsDir}/SHA256SUMS"
      echo ' '
    fi

    # NOTE: PDF conversion produces a different output every time,
    # even on the same system, so we can't use shasum to verify.
    # Maybe it includes a datetime of creation or something?
    # TODO: should we use a PDF test library like this?
    # http://jpdfunit.sourceforge.net/
    # For now, probably not, because it appears the generated PDF
    # is just a wrapper around a slightly changed PNG.
    # This PNG, however, is not identical the PNG produced via
    # pathvisio convert FILE.gpml FILE.png

    if [ -n "$(cat ${PHASHSUMS})" ]; then
      echo '  verifying perceptual hash (phash) sums...' 1>&2
      cp ${PHASHSUMS} "${testResultsDir}/PHASHSUMS"
      while IFS=" ()=" read -r alg converted blank expected;
      do
        # Uncomment the following to see which files are being checked
        #echo "    $(basename $converted)" 1>&2
        if [ -f "$converted" ]; then
          actual=$(identify -quiet -verbose -moments -alpha off "$converted" | grep "PH[1-7]" | sed -n 's/.*: \(.*\)$/\1/p' | sed 's/ *//g' | tr "\n" ",")

          sse=0
          IFS=',' read -r -a expected_arr <<< "$expected"
          IFS=',' read -r -a actual_arr <<< "$actual"

          for index in "$'' + ''{!expected_arr[@]}"; do
            exp=$'' + ''{expected_arr[index]}
            act=$'' + ''{actual_arr[index]}
            sse=$(echo "(sse + (exp - act)^2)" | bc -l)
          done

          limit=10
          if [ "$sse" -gt "$limit" ]; then
            echo "Error: pathvisio convert test failed." 1>&2
            echo "       $converted is too dissimilar from reference: $sse (should be <= $limit)" 1>&2
            exit 1;
          fi
        fi
      done < "./PHASHSUMS"

      for f in ./*.pdf; do
        base=$(basename "$f" ".pdf")
        png="$base.png"

        # Uncomment the following to see which files are being checked
        #echo "base: $base" 1>&2

        if grep -Fq "$png" ./PHASHSUMS; then
          phash=$(grep -F "$png" ./PHASHSUMS)
          IFS=" ()=" read -r alg converted blank expected <<< "$phash";

          # NOTE: when going from gpml to pdf, pathvisio converts text into paths.
          # But the PDF still seems to retain a record that it used to have certain
          # fonts, but since there are no actual fonts in the PDF, it doesn't
          # matter and we can safely ignore them. pdftocairo doesn't seem to care
          # about them, but the converter from xpdf (pdftopng) did complain.

          # These PDFs don't have images embedded in them such that we can just extract the image.
          # Proof: the following didn't extract anything:
          #   pdfimages -all "$f" ./whatever-directory-you-choose/

          # So we need to actually convert the PDF to PNG for comparison purposes:
          pdftocairo -png "$f" "$base"
          # pdftocairo automatically adds "-1.png" target name
          png="$base""-1.png"

          actual=$(identify -quiet -verbose -moments -alpha off "$png" | grep "PH[1-7]" | sed -n 's/.*: \(.*\)$/\1/p' | sed 's/ *//g' | tr "\n" ",")

          sse=0
          IFS=', ' read -r -a expected_arr <<< "$expected"
          IFS=', ' read -r -a actual_arr <<< "$actual"

          for index in "$'' + ''{!expected_arr[@]}"; do
            exp=$'' + ''{expected_arr[index]}
            act=$'' + ''{actual_arr[index]}
            sse=$(echo "(sse + (exp - act)^2)" | bc -l)
          done

          limit=10
          if [ "$sse" -gt $limit ]; then
            echo "Error: pathvisio convert test failed." 1>&2
            echo "       Bad match for $f: $sse (should be <= $limit)" 1>&2
            exit 1;
          fi

          rm "$png"
        fi
      done
    else
      PASSING=false
      echo ' '
      echo 'PHASHSUMS not set.' 1>&2
      echo "Verify the converted outputs in ${testResultsDir}" 1>&2
      echo "If they look OK, get the updated PHASHSUMS:" 1>&2
      echo "cp ${testResultsDir}/PHASHSUMS ./PHASHSUMS" 1>&2
      echo ' ' 1>&2
      touch "${testResultsDir}/PHASHSUMS"
      # NOTE: PNGs larger than limit are too big to calculate the phash
      limit=200000
      for f in ./*.png; do
        size=$(stat --printf="%s" "$f")
        if [ $size -lt $limit ]; then
          phash=$(identify -quiet -verbose -moments -alpha off "$f" | grep "PH[1-7]" | sed -n 's/.*: \(.*\)$/\1/p' | sed 's/ *//g' | tr "\n" ",")
          #echo "PHASH ($f) = $phash" | tee -a "${testResultsDir}/PHASHSUMS"
          echo "PHASH ($f) = $phash" >>"${testResultsDir}/PHASHSUMS"
        fi
      done
      echo ' '
    fi

    cat ${WP4321_98000_BASE64} | xmlstarlet sel -t -v '//ns1:data' | base64 -d - > WP4321_98000.gpml
    cat ${WP4321_98055_BASE64} | xmlstarlet sel -t -v '//ns1:data' | base64 -d - > WP4321_98055.gpml

    cd "${binPathTmp}"

    echo "  pathvisio diff" 1>&2
    ./pathvisio diff "${testResultsDir}"/WP4321_98000.gpml "${testResultsDir}"/WP4321_98055.gpml > "${testResultsDir}"/WP4321_98000_98055.patch 2>>"${logDir}/error.log"

    echo "  pathvisio patch" 1>&2
    cp "${testResultsDir}"/WP4321_98000.gpml "${testResultsDir}"/WP4321_98055.roundtrip.gpml
    ./pathvisio patch "${testResultsDir}"/WP4321_98055.roundtrip.gpml < "${testResultsDir}"/WP4321_98000_98055.patch >>"${logDir}/message.log" 2>>"${logDir}/error.log"

#    xmlstarlet tr ${XSLT_NORMALIZE} "${testResultsDir}"/WP4321_98055.gpml > "${testResultsDir}"/WP4321_98055.norm.gpml
#    xmlstarlet tr ${XSLT_NORMALIZE} "${testResultsDir}"/WP4321_98055.roundtrip.gpml > "${testResultsDir}"/WP4321_98055.roundtrip.norm.gpml
#    common=$(comm -3 --nocheck-order "${testResultsDir}"/WP4321_98055.norm.gpml "${testResultsDir}"/WP4321_98055.roundtrip.norm.gpml)
    # TODO pathvisio patch doesn't fully patch the diff between WP4321_98000 and
    # WP4321_98055, so we're forced to use the kludge of comparing just the
    # element structure instead of the actual output.
    xmlstarlet tr ${XSLT_NORMALIZE} "${testResultsDir}"/WP4321_98055.gpml | xmlstarlet el > "${testResultsDir}"/WP4321_98055.el.txt
    xmlstarlet tr ${XSLT_NORMALIZE} "${testResultsDir}"/WP4321_98055.roundtrip.gpml | xmlstarlet el > "${testResultsDir}"/WP4321_98055.roundtrip.el.txt
    common=$(comm -3 --nocheck-order "${testResultsDir}"/WP4321_98055.el.txt "${testResultsDir}"/WP4321_98055.roundtrip.el.txt)
    if [[ "$common" != "" ]]; then
      echo "Error: pathvisio patch test failed. Mis-matched content:" 1>&2
      echo "-----------------" 1>&2
      echo "$common" 1>&2
      echo "-----------------" 1>&2
      exit 1;
    fi

    echo "PASSING: $PASSING" 1>&2
    if [ ! $PASSING ]; then
      echo "Quitting because test(s) failed." 1>&2
      exit 1;
    fi

    cd "${tmpBuildDir}"
  '';

  desktopItem = makeDesktopItem {
    name = name;
    exec = "${sharePathOut}/pathvisio-launch";
    #exec = "pathvisio launch";
    #exec = "pathvisio launch ~/pathway-\$(date -j -f \"%a %b %d %T %Z %Y\" \"\$(date)\" \"+%s\").gpml";
    #exec = "pathvisio launch ~/pathway-\$(date \"+%s\").gpml";
    #exec = "pathvisio launch ~/pathway-test.gpml";
    icon = "${pngIconSrc}";
    desktopName = baseName;
    genericName = "Pathway Editor";
    comment = meta.description;
    # See https://specifications.freedesktop.org/menu-spec/latest/apa.html
    categories = "X-Editor;Science;Biology;DataVisualization;";
    mimeType = "application/gpml+xml";
    # TODO what is the terminal option?
    terminal = "false";
  };

  # TODO Should we somehow take advantage of the osgi and apache capabilities?
  #      Is the ant build process already doing this?
  installPhase = ''
    mkdir -p "${binPathOut}" "${libPathOut}" "${modulesPathOut}"

    cp -r  "${libPathSrc}"/* "${libPathOut}/"
    cp -r "${modulesPathSrc}"/* "${modulesPathOut}/"
    cp -r "${binPathTmp}"/* "${binPathOut}/"

    # To test after building, we point to source paths, but for installation,
    # we want to point to out paths.
    for f in "${binPathOut}"/*; do
      substituteInPlace $f \
            --replace "${libPathSrc}" "${libPathOut}" \
            --replace "${modulesPathSrc}" "${modulesPathOut}"
    done

    if [ -e "${logDir}/message.log" ]; then
      echo 'message log:' 1>&2
      cat "${logDir}/message.log" 1>&2
    fi
    if [ -e "${logDir}/error.log" ]; then
      echo 'error log:' 1>&2
      cat "${logDir}/error.log" 1>&2
    fi
  '' + (
  if headless then ''
    echo 'Desktop functionality not enabled.' 1>&2
  '' else ''
    mkdir -p "${sharePathOut}"
    cp "/build/source/pathvisio.jar" "${sharePathOut}/pathvisio.jar"
  '' + (
    if stdenv.system == "x86_64-darwin" then ''
      mkdir -p "$out/Applications"
      unzip -o release/${baseName}.app.zip -d "$out/Applications/"

      # TODO: look at previous JavaApplicationStub to see whether to include anything from it
      cat > $out/Applications/PathVisio.app/Contents/MacOS/JavaApplicationStub <<EOF
#! $shell
${binPathOut}/pathvisio launch
EOF
    '' else ''
      mkdir -p "$out/share/applications"
      cat >"${sharePathOut}/pathvisio-launch" <<EOF
#! $shell
${binPathOut}/pathvisio launch
EOF
      chmod a+x "${sharePathOut}/pathvisio-launch"
      ln -s ${desktopItem}/share/applications/* "$out/share/applications/"
    ''
  ));

  meta = with lib;
    { description = "A tool to create, edit and analyze biological pathways";
      longDescription = ''
        There are several options you can specify:

        * organism: the species to automatically use for new pathways (default: "Homo sapiens")
        nix-env -iA nixos.pathvisio --arg organism "Mus musculus"

        The available species are listed here:
        https://github.com/bridgedb/BridgeDb/blob/master/org.bridgedb.bio/resources/org/bridgedb/bio/organisms.txt

        * genes, interactions, metabolites: use local datasource or BridgeDb webservice (default: webservice for genes and metabolites; local for interactions)
        nix-env -iA nixos.pathvisio --arg genes "local" --arg interactions "local" --arg metabolites "local"

        * headless: CLI only (default: false)
        nix-env -iA nixos.pathvisio --arg headless true

        * Any combination of the above
        nix-env -iA nixos.pathvisio --arg organism "Mus musculus" --arg headless true --arg genes "local" --arg interactions "local"
      '';
      homepage = https://www.pathvisio.org/;
      # download_page = https://www.pathvisio.org/downloads/installation/
      # homebrew/science formula (deprecated):
      # https://github.com/Homebrew/homebrew-science/blob/51e1e3b106ced03b0e4056ef3f81d6a8729e3298/pathvisio.rb
      # brewsci/homebrew-bio formula:
      # https://github.com/brewsci/homebrew-bio/blob/master/Formula/pathvisio.rb
      license = licenses.asl20;
      maintainers = with maintainers; [ ariutta ];
      platforms = platforms.all;
    };
}
