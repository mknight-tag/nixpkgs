# This file was auto-generated by cabal2nix. Please do NOT edit manually!

{ cabal, lens, text, xmlConduit }:

cabal.mkDerivation (self: {
  pname = "xml-lens";
  version = "0.1.6.1";
  sha256 = "093grvlpm19l3g10ka82xpzl2wr0gli71kfkbvk4gvg3194fkw4h";
  buildDepends = [ lens text xmlConduit ];
  jailbreak = true;
  meta = {
    homepage = "https://github.com/fumieval/xml-lens";
    description = "Lenses, traversals, prisms for xml-conduit";
    license = self.stdenv.lib.licenses.bsd3;
    platforms = self.ghc.meta.platforms;
  };
})
