# This file was auto-generated by cabal2nix. Please do NOT edit manually!

{ cabal }:

cabal.mkDerivation (self: {
  pname = "clean-unions";
  version = "0.1";
  sha256 = "1nh4gy2ql2h9njvcx05gl2ng8g3hnvyiqq87nnh1xalsvrkh6j0v";
  meta = {
    homepage = "https://github.com/fumieval/clean-unions";
    description = "Open unions without need for Typeable";
    license = self.stdenv.lib.licenses.bsd3;
    platforms = self.ghc.meta.platforms;
    maintainers = with self.stdenv.lib.maintainers; [ fuuzetsu ];
  };
})
