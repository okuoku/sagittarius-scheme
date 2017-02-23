;; [B-283,SHA-1]
#|
  Msg = 351d43907b0f62eb5950d6045108027b4456fb44
  d = 385f5bbd23b5028a66168359927a850fe1b0e9e6c8ed351a63bc2430ffc7816e0f24ed2
  Qx = 4ea11a96ed2d2067e639fffab0c9e1b3e54288012b831c12e1a8bc5d4081e56efd9c023
  Qy = 3fae371b9688ae1551f564dfa853862f9509c0dd24a0ace85398ab80d7b460a4f51fdd8
  k = 1c659c6fbeded27fbf19495f760e47f1e956781b5d28f2b9a5de6a86cd72b11ce46d87e
  R = 3a8f6548ed8a0a14b6567b6ebac8545cef67bc2209d12419584f3a6d7272149c41a0227
  S = 188af56f110ef8135195eea4ddfc93886c5562af5e600426ab2a9223849e1e49f50bb54
|#
(test-ecdsa NIST-B-283 no-20
            #x351d43907b0f62eb5950d6045108027b4456fb44
            #x385f5bbd23b5028a66168359927a850fe1b0e9e6c8ed351a63bc2430ffc7816e0f24ed2
            #x4ea11a96ed2d2067e639fffab0c9e1b3e54288012b831c12e1a8bc5d4081e56efd9c023
            #x3fae371b9688ae1551f564dfa853862f9509c0dd24a0ace85398ab80d7b460a4f51fdd8
            #x1c659c6fbeded27fbf19495f760e47f1e956781b5d28f2b9a5de6a86cd72b11ce46d87e
            #x3a8f6548ed8a0a14b6567b6ebac8545cef67bc2209d12419584f3a6d7272149c41a0227
            #x188af56f110ef8135195eea4ddfc93886c5562af5e600426ab2a9223849e1e49f50bb54
)

;; [B-283,SHA-224]
#|
  Msg = 2da0b0949fd9e26623fe574fefde7659f5a56e6c60a3a8a75ac36d0c
  d = 299ff06e019b5f78a1aec39706b22213abb601bd62b9979bf9bc89fb702e724e3ada994
  Qx = 405030ce5c073702cffd2d273a3799a91ef916fcd35dfadcdcd7111c2315eba8ca4c5e3
  Qy = 75988c6602a132fa0541c5fda62617c65cfa17062a1c72b17c975199ca05ab72e5fe9c6
  k = 2af633ac1aee8993fc951712866d629b43ed4d568afa70287f971e8320fe17b69b34b5d
  R = 165ce308157f6ed7b5de4e2ffcaf5f7eff6cc2264f9234c61950ad7ac9e9d53b32f5b40
  S = 06e30c3406781f63d0fc5596331d476da0c038904a0aa181208052dc2ffbdb298568565
|#
(test-ecdsa NIST-B-283 no-28
            #x2da0b0949fd9e26623fe574fefde7659f5a56e6c60a3a8a75ac36d0c
            #x299ff06e019b5f78a1aec39706b22213abb601bd62b9979bf9bc89fb702e724e3ada994
            #x405030ce5c073702cffd2d273a3799a91ef916fcd35dfadcdcd7111c2315eba8ca4c5e3
            #x75988c6602a132fa0541c5fda62617c65cfa17062a1c72b17c975199ca05ab72e5fe9c6
            #x2af633ac1aee8993fc951712866d629b43ed4d568afa70287f971e8320fe17b69b34b5d
            #x165ce308157f6ed7b5de4e2ffcaf5f7eff6cc2264f9234c61950ad7ac9e9d53b32f5b40
            #x06e30c3406781f63d0fc5596331d476da0c038904a0aa181208052dc2ffbdb298568565
)

;; [B-283,SHA-256]
#|
  Msg = b53bb6c316e6f954a4167971b8cabff92ef06484c5c4ae4cc0421ca2ffa5a757
  d = 29639da33f48e4fb0d9efdf50bba550e739f0d2476385cba09d926e789191b6fb0a73ff
  Qx = 770f9693777e261db9c700eb1af0b9e9d837ce5eabd8ed7864580bfb7672ced8ffca598
  Qy = 68aef01c8126889204aaca8f3ccb089596f85e2aca773634bc5775ee4d27c77f2af83e7
  k = 32a930fdb1ba2338554a252d1bf7f0169d18750a4ec4878d2968c5e735f98b9d0c25edb
  R = 30cd65f1097d3fa0d05e1d6072675f1377a883b683c54b8a1f4960f90d68f3ee8c7bd98
  S = 15c61ddf43386a2b8cf557760200ac06a480797e21c92e45e6a311e1a508b03c4d9632e
|#
(test-ecdsa NIST-B-283 no-32
            #xb53bb6c316e6f954a4167971b8cabff92ef06484c5c4ae4cc0421ca2ffa5a757
            #x29639da33f48e4fb0d9efdf50bba550e739f0d2476385cba09d926e789191b6fb0a73ff
            #x770f9693777e261db9c700eb1af0b9e9d837ce5eabd8ed7864580bfb7672ced8ffca598
            #x68aef01c8126889204aaca8f3ccb089596f85e2aca773634bc5775ee4d27c77f2af83e7
            #x32a930fdb1ba2338554a252d1bf7f0169d18750a4ec4878d2968c5e735f98b9d0c25edb
            #x30cd65f1097d3fa0d05e1d6072675f1377a883b683c54b8a1f4960f90d68f3ee8c7bd98
            #x15c61ddf43386a2b8cf557760200ac06a480797e21c92e45e6a311e1a508b03c4d9632e
)

;; [B-283,SHA-384]
#|
  Msg = c14bd6aa9ec5b92c3e69ea088a41626d36a960a37da20fbec13fe9e17b2f5c74d53890cacef19d12f25d9b996b8b17b5
  d = 0b9f8f3e89e9c1ef835390612bfe26d714e878c1c864f0a50190e5d2281081c5083923b
  Qx = 542ea231974c079be966cf320073b0c045a2181698ae0d36a90f206ce37fa10fb905186
  Qy = 7e6eccfe1303e218b26a9f008b8b7d0c755b3c6e0892a5f572cdc16897dcf18433f9a10
  k = 31789e96e2ae53de7a7dbc3e46e9252015306d88af6bd62508554f89bb390a78fdbaf6b
  R = 0fba3bd1953a9c4cf7ce37b0cd32c0f4da0396c9f347ee2dba18d636f5c3ab058907e3e
  S = 15d1c9f7302731f8fcdc363ed2285be492cc03dd642335139ba71fbf962991bc7e45369
|#
(test-ecdsa NIST-B-283 no-48
            #xc14bd6aa9ec5b92c3e69ea088a41626d36a960a37da20fbec13fe9e17b2f5c74d53890cacef19d12f25d9b996b8b17b5
            #x0b9f8f3e89e9c1ef835390612bfe26d714e878c1c864f0a50190e5d2281081c5083923b
            #x542ea231974c079be966cf320073b0c045a2181698ae0d36a90f206ce37fa10fb905186
            #x7e6eccfe1303e218b26a9f008b8b7d0c755b3c6e0892a5f572cdc16897dcf18433f9a10
            #x31789e96e2ae53de7a7dbc3e46e9252015306d88af6bd62508554f89bb390a78fdbaf6b
            #x0fba3bd1953a9c4cf7ce37b0cd32c0f4da0396c9f347ee2dba18d636f5c3ab058907e3e
            #x15d1c9f7302731f8fcdc363ed2285be492cc03dd642335139ba71fbf962991bc7e45369
)

;; [B-283,SHA-512]
#|
  Msg = f0dfa33ce0509b71c7744b1a5b25ec37d35319486c4ae621f5ad134b1b0eedc9edb2712b8296c08b62a6ef4e66faf40eb7c4b91f8ca106a94d72c3a131eda081
  d = 1d1f2e0f044a416e1087d645f60c53cb67be2efe7944b29ac832142f13d39b08ac52931
  Qx = 10b2d7b00182ee9666a6a2bf039c4358683f234ae41a9e5485fd6594e3daa880c0dfe0f
  Qy = 0a419b2f40e573dc2dae4b22e6f56e842e50d631b6126153178585bd05a8b9e6e87e4c8
  k = 3e4d36b479773e7a01e57c88306404a46b6e62bf494b0966b4ed57e8a16169b9a1bbfe3
  R = 30513169c8874141cdf05a51f20273ac6b55fe12fa345609a2fede6acbeb110f98471af
  S = 33fd50b214f402deed1e20bd22eba71b156305e4f5a41ab9374b481ee344ab3f27f4bcd
|#
(test-ecdsa NIST-B-283 no-64
            #xf0dfa33ce0509b71c7744b1a5b25ec37d35319486c4ae621f5ad134b1b0eedc9edb2712b8296c08b62a6ef4e66faf40eb7c4b91f8ca106a94d72c3a131eda081
            #x1d1f2e0f044a416e1087d645f60c53cb67be2efe7944b29ac832142f13d39b08ac52931
            #x10b2d7b00182ee9666a6a2bf039c4358683f234ae41a9e5485fd6594e3daa880c0dfe0f
            #x0a419b2f40e573dc2dae4b22e6f56e842e50d631b6126153178585bd05a8b9e6e87e4c8
            #x3e4d36b479773e7a01e57c88306404a46b6e62bf494b0966b4ed57e8a16169b9a1bbfe3
            #x30513169c8874141cdf05a51f20273ac6b55fe12fa345609a2fede6acbeb110f98471af
            #x33fd50b214f402deed1e20bd22eba71b156305e4f5a41ab9374b481ee344ab3f27f4bcd
)

