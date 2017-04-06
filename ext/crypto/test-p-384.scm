;; [P-384,SHA-1]
#|
  Msg = 9b9f8c9535a5ca26605db7f2fa573bdfc32eab8b
  d = a492ce8fa90084c227e1a32f7974d39e9ff67a7e8705ec3419b35fb607582bebd461e0b1520ac76ec2dd4e9b63ebae71
  Qx = e55fee6c49d8d523f5ce7bf9c0425ce4ff650708b7de5cfb095901523979a7f042602db30854735369813b5c3f5ef868
  Qy = 28f59cc5dc509892a988d38a8e2519de3d0c4fd0fbdb0993e38f18506c17606c5e24249246f1ce94983a5361c5be983e
  k = ba25756f1a4a9853bbf60cb2c789569fd551abf3a9cceb889ff71ab5ef7758a3e302166bf2a01a29af18ffbd329cd781
  R = 6820b8585204648aed63bdff47f6d9acebdea62944774a7d14f0e14aa0b9a5b99545b2daee6b3c74ebf606667a3f39b7
  S = 491af1d0cccd56ddd520b233775d0bc6b40a6255cc55207d8e9356741f23c96c14714221078dbd5c17f4fdd89b32a907
|#
(test-ecdsa NIST-P-384 no-20
            #x9b9f8c9535a5ca26605db7f2fa573bdfc32eab8b
            #xa492ce8fa90084c227e1a32f7974d39e9ff67a7e8705ec3419b35fb607582bebd461e0b1520ac76ec2dd4e9b63ebae71
            #xe55fee6c49d8d523f5ce7bf9c0425ce4ff650708b7de5cfb095901523979a7f042602db30854735369813b5c3f5ef868
            #x28f59cc5dc509892a988d38a8e2519de3d0c4fd0fbdb0993e38f18506c17606c5e24249246f1ce94983a5361c5be983e
            #xba25756f1a4a9853bbf60cb2c789569fd551abf3a9cceb889ff71ab5ef7758a3e302166bf2a01a29af18ffbd329cd781
            #x6820b8585204648aed63bdff47f6d9acebdea62944774a7d14f0e14aa0b9a5b99545b2daee6b3c74ebf606667a3f39b7
            #x491af1d0cccd56ddd520b233775d0bc6b40a6255cc55207d8e9356741f23c96c14714221078dbd5c17f4fdd89b32a907
)

;; [P-384,SHA-224]
#|
  Msg = 5e3b235f5a8037f7556331ed6e9b503fd9f4d6e7d5851d8716780e00
  d = 0af857beff08046f23b03c4299eda86490393bde88e4f74348886b200555276b93b37d4f6fdec17c0ea581a30c59c727
  Qx = 00ea9d109dbaa3900461a9236453952b1f1c2a5aa12f6d500ac774acdff84ab7cb71a0f91bcd55aaa57cb8b4fbb3087d
  Qy = 0fc0e3116c9e94be583b02b21b1eb168d8facf3955279360cbcd86e04ee50751054cfaebcf542538ac113d56ccc38b3e
  k = e2f0ce83c5bbef3a6eccd1744f893bb52952475d2531a2854a88ff0aa9b12c65961e2e517fb334ef40e0c0d7a31ed5f5
  R = c36e5f0d3de71411e6e519f63e0f56cff432330a04fefef2993fdb56343e49f2f7db5fcab7728acc1e33d4692553c02e
  S = 0d4064399d58cd771ab9420d438757f5936c3808e97081e457bc862a0c905295dca60ee94f4537591c6c7d217453909b
|#
(test-ecdsa NIST-P-384 no-28
            #x5e3b235f5a8037f7556331ed6e9b503fd9f4d6e7d5851d8716780e00
            #x0af857beff08046f23b03c4299eda86490393bde88e4f74348886b200555276b93b37d4f6fdec17c0ea581a30c59c727
            #x00ea9d109dbaa3900461a9236453952b1f1c2a5aa12f6d500ac774acdff84ab7cb71a0f91bcd55aaa57cb8b4fbb3087d
            #x0fc0e3116c9e94be583b02b21b1eb168d8facf3955279360cbcd86e04ee50751054cfaebcf542538ac113d56ccc38b3e
            #xe2f0ce83c5bbef3a6eccd1744f893bb52952475d2531a2854a88ff0aa9b12c65961e2e517fb334ef40e0c0d7a31ed5f5
            #xc36e5f0d3de71411e6e519f63e0f56cff432330a04fefef2993fdb56343e49f2f7db5fcab7728acc1e33d4692553c02e
            #x0d4064399d58cd771ab9420d438757f5936c3808e97081e457bc862a0c905295dca60ee94f4537591c6c7d217453909b
)

;; [P-384,SHA-256]
#|
  Msg = bbbd0a5f645d3fda10e288d172b299455f9dff00e0fbc2833e18cd017d7f3ed1
  d = c602bc74a34592c311a6569661e0832c84f7207274676cc42a89f058162630184b52f0d99b855a7783c987476d7f9e6b
  Qx = 0400193b21f07cd059826e9453d3e96dd145041c97d49ff6b7047f86bb0b0439e909274cb9c282bfab88674c0765bc75
  Qy = f70d89c52acbc70468d2c5ae75c76d7f69b76af62dcf95e99eba5dd11adf8f42ec9a425b0c5ec98e2f234a926b82a147
  k = c10b5c25c4683d0b7827d0d88697cdc0932496b5299b798c0dd1e7af6cc757ccb30fcd3d36ead4a804877e24f3a32443
  R = b11db00cdaf53286d4483f38cd02785948477ed7ebc2ad609054551da0ab0359978c61851788aa2ec3267946d440e878
  S = 16007873c5b0604ce68112a8fee973e8e2b6e3319c683a762ff5065a076512d7c98b27e74b7887671048ac027df8cbf2
|#
(test-ecdsa NIST-P-384 no-32
            #xbbbd0a5f645d3fda10e288d172b299455f9dff00e0fbc2833e18cd017d7f3ed1
            #xc602bc74a34592c311a6569661e0832c84f7207274676cc42a89f058162630184b52f0d99b855a7783c987476d7f9e6b
            #x0400193b21f07cd059826e9453d3e96dd145041c97d49ff6b7047f86bb0b0439e909274cb9c282bfab88674c0765bc75
            #xf70d89c52acbc70468d2c5ae75c76d7f69b76af62dcf95e99eba5dd11adf8f42ec9a425b0c5ec98e2f234a926b82a147
            #xc10b5c25c4683d0b7827d0d88697cdc0932496b5299b798c0dd1e7af6cc757ccb30fcd3d36ead4a804877e24f3a32443
            #xb11db00cdaf53286d4483f38cd02785948477ed7ebc2ad609054551da0ab0359978c61851788aa2ec3267946d440e878
            #x16007873c5b0604ce68112a8fee973e8e2b6e3319c683a762ff5065a076512d7c98b27e74b7887671048ac027df8cbf2
)

;; [P-384,SHA-384]
#|
  Msg = 31a452d6164d904bb5724c878280231eae705c29ce9d4bc7d58e020e1085f17eebcc1a38f0ed0bf2b344d81fbd896825
  d = 201b432d8df14324182d6261db3e4b3f46a8284482d52e370da41e6cbdf45ec2952f5db7ccbce3bc29449f4fb080ac97
  Qx = c2b47944fb5de342d03285880177ca5f7d0f2fcad7678cce4229d6e1932fcac11bfc3c3e97d942a3c56bf34123013dbf
  Qy = 37257906a8223866eda0743c519616a76a758ae58aee81c5fd35fbf3a855b7754a36d4a0672df95d6c44a81cf7620c2d
  k = dcedabf85978e090f733c6e16646fa34df9ded6e5ce28c6676a00f58a25283db8885e16ce5bf97f917c81e1f25c9c771
  R = 50835a9251bad008106177ef004b091a1e4235cd0da84fff54542b0ed755c1d6f251609d14ecf18f9e1ddfe69b946e32
  S = 0475f3d30c6463b646e8d3bf2455830314611cbde404be518b14464fdb195fdcc92eb222e61f426a4a592c00a6a89721
|#
(test-ecdsa NIST-P-384 no-48
            #x31a452d6164d904bb5724c878280231eae705c29ce9d4bc7d58e020e1085f17eebcc1a38f0ed0bf2b344d81fbd896825
            #x201b432d8df14324182d6261db3e4b3f46a8284482d52e370da41e6cbdf45ec2952f5db7ccbce3bc29449f4fb080ac97
            #xc2b47944fb5de342d03285880177ca5f7d0f2fcad7678cce4229d6e1932fcac11bfc3c3e97d942a3c56bf34123013dbf
            #x37257906a8223866eda0743c519616a76a758ae58aee81c5fd35fbf3a855b7754a36d4a0672df95d6c44a81cf7620c2d
            #xdcedabf85978e090f733c6e16646fa34df9ded6e5ce28c6676a00f58a25283db8885e16ce5bf97f917c81e1f25c9c771
            #x50835a9251bad008106177ef004b091a1e4235cd0da84fff54542b0ed755c1d6f251609d14ecf18f9e1ddfe69b946e32
            #x0475f3d30c6463b646e8d3bf2455830314611cbde404be518b14464fdb195fdcc92eb222e61f426a4a592c00a6a89721
)

;; [P-384,SHA-512]
#|
  Msg = f863cf3749ae5256da0ceb2e6d391fcce939b1490b024527687b1a2908da35c48b44255d82956c76d70672c41c6456d78c57342e932490083f73016b560a0245
  d = 217afba406d8ab32ee07b0f27eef789fc201d121ffab76c8fbe3c2d352c594909abe591c6f86233992362c9d631baf7c
  Qx = fb937e4a303617b71b6c1a25f2ac786087328a3e26bdef55e52d46ab5e69e5411bf9fc55f5df9994d2bf82e8f39a153e
  Qy = a97d9075e92fa5bfe67e6ec18e21cc4d11fde59a68aef72c0e46a28f31a9d60385f41f39da468f4e6c3d3fbac9046765
  k = 90338a7f6ffce541366ca2987c3b3ca527992d1efcf1dd2723fbd241a24cff19990f2af5fd6419ed2104b4a59b5ae631
  R = c269d9c4619aafdf5f4b3100211dddb14693abe25551e04f9499c91152a296d7449c08b36f87d1e16e8e15fee4a7f5c8
  S = 77ffed5c61665152d52161dc13ac3fbae5786928a3d736f42d34a9e4d6d4a70a02d5af90fa37a23a318902ae2656c071
|#
(test-ecdsa NIST-P-384 no-64
            #xf863cf3749ae5256da0ceb2e6d391fcce939b1490b024527687b1a2908da35c48b44255d82956c76d70672c41c6456d78c57342e932490083f73016b560a0245
            #x217afba406d8ab32ee07b0f27eef789fc201d121ffab76c8fbe3c2d352c594909abe591c6f86233992362c9d631baf7c
            #xfb937e4a303617b71b6c1a25f2ac786087328a3e26bdef55e52d46ab5e69e5411bf9fc55f5df9994d2bf82e8f39a153e
            #xa97d9075e92fa5bfe67e6ec18e21cc4d11fde59a68aef72c0e46a28f31a9d60385f41f39da468f4e6c3d3fbac9046765
            #x90338a7f6ffce541366ca2987c3b3ca527992d1efcf1dd2723fbd241a24cff19990f2af5fd6419ed2104b4a59b5ae631
            #xc269d9c4619aafdf5f4b3100211dddb14693abe25551e04f9499c91152a296d7449c08b36f87d1e16e8e15fee4a7f5c8
            #x77ffed5c61665152d52161dc13ac3fbae5786928a3d736f42d34a9e4d6d4a70a02d5af90fa37a23a318902ae2656c071
)
