export const KarmaAllocatedPresaleAbi = [
  {
    type: "constructor",
    inputs: [
      {
        name: "owner_",
        type: "address",
        internalType: "address",
      },
      {
        name: "factory_",
        type: "address",
        internalType: "address",
      },
      {
        name: "usdc_",
        type: "address",
        internalType: "address",
      },
      {
        name: "karmaFeeRecipient_",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "ALLOCATION_DEADLINE_BUFFER",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "BPS",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "MAX_PRESALE_DURATION",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "SALT_SET_BUFFER",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "admins",
    inputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "batchSetMaxAcceptedUsdc",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "users",
        type: "address[]",
        internalType: "address[]",
      },
      {
        name: "maxUsdcAmounts",
        type: "uint256[]",
        internalType: "uint256[]",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "claim",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "tokenAmount",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "refundAmount",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "claimUsdc",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "recipient",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "contribute",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "amount",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "contributions",
    inputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "createPresale",
    inputs: [
      {
        name: "presaleOwner",
        type: "address",
        internalType: "address",
      },
      {
        name: "targetUsdc",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "minUsdc",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "duration",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "deploymentConfig",
        type: "tuple",
        internalType: "struct IKarma.DeploymentConfig",
        components: [
          {
            name: "tokenConfig",
            type: "tuple",
            internalType: "struct IKarma.TokenConfig",
            components: [
              {
                name: "tokenAdmin",
                type: "address",
                internalType: "address",
              },
              {
                name: "name",
                type: "string",
                internalType: "string",
              },
              {
                name: "symbol",
                type: "string",
                internalType: "string",
              },
              {
                name: "salt",
                type: "bytes32",
                internalType: "bytes32",
              },
              {
                name: "image",
                type: "string",
                internalType: "string",
              },
              {
                name: "metadata",
                type: "string",
                internalType: "string",
              },
              {
                name: "context",
                type: "string",
                internalType: "string",
              },
              {
                name: "originatingChainId",
                type: "uint256",
                internalType: "uint256",
              },
            ],
          },
          {
            name: "poolConfig",
            type: "tuple",
            internalType: "struct IKarma.PoolConfig",
            components: [
              {
                name: "hook",
                type: "address",
                internalType: "address",
              },
              {
                name: "pairedToken",
                type: "address",
                internalType: "address",
              },
              {
                name: "tickIfToken0IsKarma",
                type: "int24",
                internalType: "int24",
              },
              {
                name: "tickSpacing",
                type: "int24",
                internalType: "int24",
              },
              {
                name: "poolData",
                type: "bytes",
                internalType: "bytes",
              },
            ],
          },
          {
            name: "lockerConfig",
            type: "tuple",
            internalType: "struct IKarma.LockerConfig",
            components: [
              {
                name: "locker",
                type: "address",
                internalType: "address",
              },
              {
                name: "rewardAdmins",
                type: "address[]",
                internalType: "address[]",
              },
              {
                name: "rewardRecipients",
                type: "address[]",
                internalType: "address[]",
              },
              {
                name: "rewardBps",
                type: "uint16[]",
                internalType: "uint16[]",
              },
              {
                name: "tickLower",
                type: "int24[]",
                internalType: "int24[]",
              },
              {
                name: "tickUpper",
                type: "int24[]",
                internalType: "int24[]",
              },
              {
                name: "positionBps",
                type: "uint16[]",
                internalType: "uint16[]",
              },
              {
                name: "lockerData",
                type: "bytes",
                internalType: "bytes",
              },
            ],
          },
          {
            name: "mevModuleConfig",
            type: "tuple",
            internalType: "struct IKarma.MevModuleConfig",
            components: [
              {
                name: "mevModule",
                type: "address",
                internalType: "address",
              },
              {
                name: "mevModuleData",
                type: "bytes",
                internalType: "bytes",
              },
            ],
          },
          {
            name: "extensionConfigs",
            type: "tuple[]",
            internalType: "struct IKarma.ExtensionConfig[]",
            components: [
              {
                name: "extension",
                type: "address",
                internalType: "address",
              },
              {
                name: "msgValue",
                type: "uint256",
                internalType: "uint256",
              },
              {
                name: "extensionBps",
                type: "uint16",
                internalType: "uint16",
              },
              {
                name: "extensionData",
                type: "bytes",
                internalType: "bytes",
              },
            ],
          },
        ],
      },
    ],
    outputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "factory",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "contract IKarma",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getAcceptedContribution",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "user",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getContribution",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "user",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getMaxAcceptedUsdc",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "user",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getPresale",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "tuple",
        internalType: "struct IKarmaAllocatedPresale.Presale",
        components: [
          {
            name: "status",
            type: "uint8",
            internalType: "enum IKarmaAllocatedPresale.PresaleStatus",
          },
          {
            name: "deploymentConfig",
            type: "tuple",
            internalType: "struct IKarma.DeploymentConfig",
            components: [
              {
                name: "tokenConfig",
                type: "tuple",
                internalType: "struct IKarma.TokenConfig",
                components: [
                  {
                    name: "tokenAdmin",
                    type: "address",
                    internalType: "address",
                  },
                  {
                    name: "name",
                    type: "string",
                    internalType: "string",
                  },
                  {
                    name: "symbol",
                    type: "string",
                    internalType: "string",
                  },
                  {
                    name: "salt",
                    type: "bytes32",
                    internalType: "bytes32",
                  },
                  {
                    name: "image",
                    type: "string",
                    internalType: "string",
                  },
                  {
                    name: "metadata",
                    type: "string",
                    internalType: "string",
                  },
                  {
                    name: "context",
                    type: "string",
                    internalType: "string",
                  },
                  {
                    name: "originatingChainId",
                    type: "uint256",
                    internalType: "uint256",
                  },
                ],
              },
              {
                name: "poolConfig",
                type: "tuple",
                internalType: "struct IKarma.PoolConfig",
                components: [
                  {
                    name: "hook",
                    type: "address",
                    internalType: "address",
                  },
                  {
                    name: "pairedToken",
                    type: "address",
                    internalType: "address",
                  },
                  {
                    name: "tickIfToken0IsKarma",
                    type: "int24",
                    internalType: "int24",
                  },
                  {
                    name: "tickSpacing",
                    type: "int24",
                    internalType: "int24",
                  },
                  {
                    name: "poolData",
                    type: "bytes",
                    internalType: "bytes",
                  },
                ],
              },
              {
                name: "lockerConfig",
                type: "tuple",
                internalType: "struct IKarma.LockerConfig",
                components: [
                  {
                    name: "locker",
                    type: "address",
                    internalType: "address",
                  },
                  {
                    name: "rewardAdmins",
                    type: "address[]",
                    internalType: "address[]",
                  },
                  {
                    name: "rewardRecipients",
                    type: "address[]",
                    internalType: "address[]",
                  },
                  {
                    name: "rewardBps",
                    type: "uint16[]",
                    internalType: "uint16[]",
                  },
                  {
                    name: "tickLower",
                    type: "int24[]",
                    internalType: "int24[]",
                  },
                  {
                    name: "tickUpper",
                    type: "int24[]",
                    internalType: "int24[]",
                  },
                  {
                    name: "positionBps",
                    type: "uint16[]",
                    internalType: "uint16[]",
                  },
                  {
                    name: "lockerData",
                    type: "bytes",
                    internalType: "bytes",
                  },
                ],
              },
              {
                name: "mevModuleConfig",
                type: "tuple",
                internalType: "struct IKarma.MevModuleConfig",
                components: [
                  {
                    name: "mevModule",
                    type: "address",
                    internalType: "address",
                  },
                  {
                    name: "mevModuleData",
                    type: "bytes",
                    internalType: "bytes",
                  },
                ],
              },
              {
                name: "extensionConfigs",
                type: "tuple[]",
                internalType: "struct IKarma.ExtensionConfig[]",
                components: [
                  {
                    name: "extension",
                    type: "address",
                    internalType: "address",
                  },
                  {
                    name: "msgValue",
                    type: "uint256",
                    internalType: "uint256",
                  },
                  {
                    name: "extensionBps",
                    type: "uint16",
                    internalType: "uint16",
                  },
                  {
                    name: "extensionData",
                    type: "bytes",
                    internalType: "bytes",
                  },
                ],
              },
            ],
          },
          {
            name: "presaleOwner",
            type: "address",
            internalType: "address",
          },
          {
            name: "targetUsdc",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "minUsdc",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "endTime",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "allocationDeadline",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "totalContributions",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "deployedToken",
            type: "address",
            internalType: "address",
          },
          {
            name: "tokenSupply",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "usdcClaimed",
            type: "bool",
            internalType: "bool",
          },
          {
            name: "karmaFeeBps",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getPresaleStatus",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint8",
        internalType: "enum IKarmaAllocatedPresale.PresaleStatus",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getRefundAmount",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "user",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getTokenAllocation",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "user",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getTotalAcceptedUsdc",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "karmaDefaultFeeBps",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "karmaFeeRecipient",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "maxAcceptedUsdc",
    inputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "owner",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "prepareForDeployment",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "salt",
        type: "bytes32",
        internalType: "bytes32",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "presaleState",
    inputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "status",
        type: "uint8",
        internalType: "enum IKarmaAllocatedPresale.PresaleStatus",
      },
      {
        name: "deploymentConfig",
        type: "tuple",
        internalType: "struct IKarma.DeploymentConfig",
        components: [
          {
            name: "tokenConfig",
            type: "tuple",
            internalType: "struct IKarma.TokenConfig",
            components: [
              {
                name: "tokenAdmin",
                type: "address",
                internalType: "address",
              },
              {
                name: "name",
                type: "string",
                internalType: "string",
              },
              {
                name: "symbol",
                type: "string",
                internalType: "string",
              },
              {
                name: "salt",
                type: "bytes32",
                internalType: "bytes32",
              },
              {
                name: "image",
                type: "string",
                internalType: "string",
              },
              {
                name: "metadata",
                type: "string",
                internalType: "string",
              },
              {
                name: "context",
                type: "string",
                internalType: "string",
              },
              {
                name: "originatingChainId",
                type: "uint256",
                internalType: "uint256",
              },
            ],
          },
          {
            name: "poolConfig",
            type: "tuple",
            internalType: "struct IKarma.PoolConfig",
            components: [
              {
                name: "hook",
                type: "address",
                internalType: "address",
              },
              {
                name: "pairedToken",
                type: "address",
                internalType: "address",
              },
              {
                name: "tickIfToken0IsKarma",
                type: "int24",
                internalType: "int24",
              },
              {
                name: "tickSpacing",
                type: "int24",
                internalType: "int24",
              },
              {
                name: "poolData",
                type: "bytes",
                internalType: "bytes",
              },
            ],
          },
          {
            name: "lockerConfig",
            type: "tuple",
            internalType: "struct IKarma.LockerConfig",
            components: [
              {
                name: "locker",
                type: "address",
                internalType: "address",
              },
              {
                name: "rewardAdmins",
                type: "address[]",
                internalType: "address[]",
              },
              {
                name: "rewardRecipients",
                type: "address[]",
                internalType: "address[]",
              },
              {
                name: "rewardBps",
                type: "uint16[]",
                internalType: "uint16[]",
              },
              {
                name: "tickLower",
                type: "int24[]",
                internalType: "int24[]",
              },
              {
                name: "tickUpper",
                type: "int24[]",
                internalType: "int24[]",
              },
              {
                name: "positionBps",
                type: "uint16[]",
                internalType: "uint16[]",
              },
              {
                name: "lockerData",
                type: "bytes",
                internalType: "bytes",
              },
            ],
          },
          {
            name: "mevModuleConfig",
            type: "tuple",
            internalType: "struct IKarma.MevModuleConfig",
            components: [
              {
                name: "mevModule",
                type: "address",
                internalType: "address",
              },
              {
                name: "mevModuleData",
                type: "bytes",
                internalType: "bytes",
              },
            ],
          },
          {
            name: "extensionConfigs",
            type: "tuple[]",
            internalType: "struct IKarma.ExtensionConfig[]",
            components: [
              {
                name: "extension",
                type: "address",
                internalType: "address",
              },
              {
                name: "msgValue",
                type: "uint256",
                internalType: "uint256",
              },
              {
                name: "extensionBps",
                type: "uint16",
                internalType: "uint16",
              },
              {
                name: "extensionData",
                type: "bytes",
                internalType: "bytes",
              },
            ],
          },
        ],
      },
      {
        name: "presaleOwner",
        type: "address",
        internalType: "address",
      },
      {
        name: "targetUsdc",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "minUsdc",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "endTime",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "allocationDeadline",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "totalContributions",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "deployedToken",
        type: "address",
        internalType: "address",
      },
      {
        name: "tokenSupply",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "usdcClaimed",
        type: "bool",
        internalType: "bool",
      },
      {
        name: "karmaFeeBps",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "receiveTokens",
    inputs: [
      {
        name: "deploymentConfig",
        type: "tuple",
        internalType: "struct IKarma.DeploymentConfig",
        components: [
          {
            name: "tokenConfig",
            type: "tuple",
            internalType: "struct IKarma.TokenConfig",
            components: [
              {
                name: "tokenAdmin",
                type: "address",
                internalType: "address",
              },
              {
                name: "name",
                type: "string",
                internalType: "string",
              },
              {
                name: "symbol",
                type: "string",
                internalType: "string",
              },
              {
                name: "salt",
                type: "bytes32",
                internalType: "bytes32",
              },
              {
                name: "image",
                type: "string",
                internalType: "string",
              },
              {
                name: "metadata",
                type: "string",
                internalType: "string",
              },
              {
                name: "context",
                type: "string",
                internalType: "string",
              },
              {
                name: "originatingChainId",
                type: "uint256",
                internalType: "uint256",
              },
            ],
          },
          {
            name: "poolConfig",
            type: "tuple",
            internalType: "struct IKarma.PoolConfig",
            components: [
              {
                name: "hook",
                type: "address",
                internalType: "address",
              },
              {
                name: "pairedToken",
                type: "address",
                internalType: "address",
              },
              {
                name: "tickIfToken0IsKarma",
                type: "int24",
                internalType: "int24",
              },
              {
                name: "tickSpacing",
                type: "int24",
                internalType: "int24",
              },
              {
                name: "poolData",
                type: "bytes",
                internalType: "bytes",
              },
            ],
          },
          {
            name: "lockerConfig",
            type: "tuple",
            internalType: "struct IKarma.LockerConfig",
            components: [
              {
                name: "locker",
                type: "address",
                internalType: "address",
              },
              {
                name: "rewardAdmins",
                type: "address[]",
                internalType: "address[]",
              },
              {
                name: "rewardRecipients",
                type: "address[]",
                internalType: "address[]",
              },
              {
                name: "rewardBps",
                type: "uint16[]",
                internalType: "uint16[]",
              },
              {
                name: "tickLower",
                type: "int24[]",
                internalType: "int24[]",
              },
              {
                name: "tickUpper",
                type: "int24[]",
                internalType: "int24[]",
              },
              {
                name: "positionBps",
                type: "uint16[]",
                internalType: "uint16[]",
              },
              {
                name: "lockerData",
                type: "bytes",
                internalType: "bytes",
              },
            ],
          },
          {
            name: "mevModuleConfig",
            type: "tuple",
            internalType: "struct IKarma.MevModuleConfig",
            components: [
              {
                name: "mevModule",
                type: "address",
                internalType: "address",
              },
              {
                name: "mevModuleData",
                type: "bytes",
                internalType: "bytes",
              },
            ],
          },
          {
            name: "extensionConfigs",
            type: "tuple[]",
            internalType: "struct IKarma.ExtensionConfig[]",
            components: [
              {
                name: "extension",
                type: "address",
                internalType: "address",
              },
              {
                name: "msgValue",
                type: "uint256",
                internalType: "uint256",
              },
              {
                name: "extensionBps",
                type: "uint16",
                internalType: "uint16",
              },
              {
                name: "extensionData",
                type: "bytes",
                internalType: "bytes",
              },
            ],
          },
        ],
      },
      {
        name: "",
        type: "tuple",
        internalType: "struct PoolKey",
        components: [
          {
            name: "currency0",
            type: "address",
            internalType: "Currency",
          },
          {
            name: "currency1",
            type: "address",
            internalType: "Currency",
          },
          {
            name: "fee",
            type: "uint24",
            internalType: "uint24",
          },
          {
            name: "tickSpacing",
            type: "int24",
            internalType: "int24",
          },
          {
            name: "hooks",
            type: "address",
            internalType: "contract IHooks",
          },
        ],
      },
      {
        name: "token",
        type: "address",
        internalType: "address",
      },
      {
        name: "extensionSupply",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "extensionIndex",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "refundClaimed",
    inputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "renounceOwnership",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "saltSet",
    inputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "setAdmin",
    inputs: [
      {
        name: "admin",
        type: "address",
        internalType: "address",
      },
      {
        name: "enabled",
        type: "bool",
        internalType: "bool",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "setKarmaDefaultFee",
    inputs: [
      {
        name: "newFeeBps",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "setKarmaFeeForPresale",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "newFeeBps",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "setKarmaFeeRecipient",
    inputs: [
      {
        name: "newRecipient",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "setMaxAcceptedUsdc",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "user",
        type: "address",
        internalType: "address",
      },
      {
        name: "maxUsdc",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "supportsInterface",
    inputs: [
      {
        name: "interfaceId",
        type: "bytes4",
        internalType: "bytes4",
      },
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "pure",
  },
  {
    type: "function",
    name: "tokensClaimed",
    inputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "totalAcceptedUsdc",
    inputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "transferOwnership",
    inputs: [
      {
        name: "newOwner",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "usdc",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "contract IERC20",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "withdrawContribution",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "amount",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "event",
    name: "Contribution",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "contributor",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "amount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "totalContributions",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "ContributionWithdrawn",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "contributor",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "amount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "totalContributions",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "KarmaDefaultFeeUpdated",
    inputs: [
      {
        name: "oldFee",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "newFee",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "KarmaFeeRecipientUpdated",
    inputs: [
      {
        name: "oldRecipient",
        type: "address",
        indexed: false,
        internalType: "address",
      },
      {
        name: "newRecipient",
        type: "address",
        indexed: false,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "KarmaFeeUpdatedForPresale",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "oldFee",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "newFee",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "MaxAcceptedUsdcSet",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "user",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "maxUsdc",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "acceptedUsdc",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "OwnershipTransferred",
    inputs: [
      {
        name: "previousOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "newOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "PresaleCreated",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "presaleOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "targetUsdc",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "minUsdc",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "endTime",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "allocationDeadline",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "karmaFeeBps",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "PresaleReadyForDeployment",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "salt",
        type: "bytes32",
        indexed: false,
        internalType: "bytes32",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "RefundClaimed",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "user",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "refundAmount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "SetAdmin",
    inputs: [
      {
        name: "admin",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "enabled",
        type: "bool",
        indexed: false,
        internalType: "bool",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "TokensClaimed",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "user",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "tokenAmount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "TokensReceived",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "token",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "tokenSupply",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "UsdcClaimed",
    inputs: [
      {
        name: "presaleId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "recipient",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "amount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "fee",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "error",
    name: "AllocationDeadlineExpired",
    inputs: [],
  },
  {
    type: "error",
    name: "AlreadyClaimed",
    inputs: [],
  },
  {
    type: "error",
    name: "ContributionWindowEnded",
    inputs: [],
  },
  {
    type: "error",
    name: "ContributionWindowNotEnded",
    inputs: [],
  },
  {
    type: "error",
    name: "InsufficientBalance",
    inputs: [],
  },
  {
    type: "error",
    name: "InsufficientContribution",
    inputs: [],
  },
  {
    type: "error",
    name: "InvalidKarmaFee",
    inputs: [],
  },
  {
    type: "error",
    name: "InvalidMsgValue",
    inputs: [],
  },
  {
    type: "error",
    name: "InvalidPresale",
    inputs: [],
  },
  {
    type: "error",
    name: "InvalidPresaleDuration",
    inputs: [],
  },
  {
    type: "error",
    name: "InvalidPresaleOwner",
    inputs: [],
  },
  {
    type: "error",
    name: "InvalidPresaleStatus",
    inputs: [
      {
        name: "current",
        type: "uint8",
        internalType: "enum IKarmaAllocatedPresale.PresaleStatus",
      },
      {
        name: "expected",
        type: "uint8",
        internalType: "enum IKarmaAllocatedPresale.PresaleStatus",
      },
    ],
  },
  {
    type: "error",
    name: "InvalidRecipient",
    inputs: [],
  },
  {
    type: "error",
    name: "InvalidUsdcGoal",
    inputs: [],
  },
  {
    type: "error",
    name: "LengthMismatch",
    inputs: [],
  },
  {
    type: "error",
    name: "NotExpectingTokenDeployment",
    inputs: [],
  },
  {
    type: "error",
    name: "NothingToClaim",
    inputs: [],
  },
  {
    type: "error",
    name: "OwnableInvalidOwner",
    inputs: [
      {
        name: "owner",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "OwnableUnauthorizedAccount",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "PresaleNotActive",
    inputs: [],
  },
  {
    type: "error",
    name: "PresaleNotClaimable",
    inputs: [],
  },
  {
    type: "error",
    name: "PresaleNotFailed",
    inputs: [],
  },
  {
    type: "error",
    name: "PresaleNotLastExtension",
    inputs: [],
  },
  {
    type: "error",
    name: "PresaleNotReadyForAllocation",
    inputs: [],
  },
  {
    type: "error",
    name: "PresaleNotReadyForDeployment",
    inputs: [],
  },
  {
    type: "error",
    name: "PresaleSupplyZero",
    inputs: [],
  },
  {
    type: "error",
    name: "ReentrancyGuardReentrantCall",
    inputs: [],
  },
  {
    type: "error",
    name: "SafeERC20FailedOperation",
    inputs: [
      {
        name: "token",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "SaltBufferNotExpired",
    inputs: [],
  },
  {
    type: "error",
    name: "Unauthorized",
    inputs: [],
  },
] as const;
