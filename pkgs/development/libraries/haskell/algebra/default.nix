# This file was auto-generated by cabal2nix. Please do NOT edit manually!

{ cabal, adjunctions, distributive, mtl, nats, semigroupoids
, semigroups, tagged, transformers, void
}:

cabal.mkDerivation (self: {
  pname = "algebra";
  version = "4.1";
  sha256 = "1wcwpngaqnr9w89p5dycmpsaihdwqqrs2vjap6jfwrscq16yyyc6";
  buildDepends = [
    adjunctions distributive mtl nats semigroupoids semigroups tagged
    transformers void
  ];
  meta = {
    homepage = "http://github.com/ekmett/algebra/";
    description = "Constructive abstract algebra";
    license = self.stdenv.lib.licenses.bsd3;
    platforms = self.ghc.meta.platforms;
  };
})
