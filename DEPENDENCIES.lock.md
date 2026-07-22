# Hardened build dependency lock

This branch builds upstream `csgo_gc` commit
`35855041f70c060928e28b9c000aabf0dfd8c96a` with immutable dependency commits.
The moving dependencies were resolved at the upstream release time,
2026-07-20 15:36:31 UTC.

| Dependency | Commit | Source |
| --- | --- | --- |
| protobuf | `2798a968c330de223b711e4fe504800280f333fb` | Existing upstream CMake pin |
| cryptopp-cmake | `866aceb8b13b6427a3c4541288ff412ad54f11ea` | `vendor/cryptopp-cmake` submodule |
| Crypto++ | `fe62c6a03c69fb322faf282c6f69b0b0f0d965eb` | `vendor/cryptopp` submodule |
| funchook | `b4991704add411ecbc492dae020f375124d51f45` | `vendor/funchook` submodule |
| diStorm | `ed2d3916a83998c9de83924855a6e9ff40f9f17d` | `vendor/distorm` submodule |

Windows x86 selects diStorm through funchook. Capstone, Zydis, and cryptopp-pem
are not selected or fetched. Crypto++ is supplied through `CRYPTOPP_SOURCES`;
diStorm is supplied through CMake's `FETCHCONTENT_SOURCE_DIR_DISTORM` override.
