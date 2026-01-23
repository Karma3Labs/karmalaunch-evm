# Karma Reputation Presale

```
════════════════════════════════════════════════════════════════════════════════════════════════════
                                    FULL PRESALE TIMELINE
════════════════════════════════════════════════════════════════════════════════════════════════════


DAY 0                                                           
──────────────────────────────────────────────────────────────────
│
│  ┌─────────────────────────────────────────────────────────┐
│  │  STEP 1: ADMIN CREATES PRESALE                          │
│  └─────────────────────────────────────────────────────────┘
│
│     admin calls presale.createPresale(
│         presaleOwner,
│         targetUsdc:    100,000 USDC,
│         minUsdc:        50,000 USDC,
│         duration:            7 days,
│         scoreUploadBuffer:   2 days,
│         lockupDuration:      7 days,
│         vestingDuration:    30 days,
│         reputationContext:   0x8337...
│     )
│
│     ─► emit PresaleCreated { presaleId: 1 }
│     ─► Status: ACTIVE
│
│
DAY 0-7: CONTRIBUTION WINDOW                                     
──────────────────────────────────────────────────────────────────
│
│  ┌─────────────────────────────────────────────────────────┐
│  │  STEP 2: USERS CONTRIBUTE USDC                          │
│  └─────────────────────────────────────────────────────────┘
│
│     alice   calls presale.contribute(40,000 USDC)
│             ─► emit Contribution { contributor: alice, amount: 40,000, totalRaised: 40,000 }
│
│     bob     calls presale.contribute(25,000 USDC)
│             ─► emit Contribution { contributor: bob, amount: 25,000, totalRaised: 65,000 }
│
│     charlie calls presale.contribute(20,000 USDC)
│             ─► emit Contribution { contributor: charlie, amount: 20,000, totalRaised: 85,000 }
│
│     diana   calls presale.contribute(10,000 USDC)
│             ─► emit Contribution { contributor: diana, amount: 10,000, totalRaised: 95,000 }
│
│     ┌──────────────────────────────────────┐
│     │  CONTRIBUTIONS SUMMARY               │
│     │  ────────────────────────────────    │
│     │  Alice:    40,000 USDC               │
│     │  Bob:      25,000 USDC               │
│     │  Charlie:  20,000 USDC               │
│     │  Diana:    10,000 USDC               │
│     │  ────────────────────────────────    │
│     │  TOTAL:    95,000 USDC               │
│     └──────────────────────────────────────┘
│
│
DAY 7: CONTRIBUTION WINDOW ENDS                                   
──────────────────────────────────────────────────────────────────
│
│     totalContributions (95,000) >= minUsdc (50,000) ?
│     YES ─► Status: PENDING_SCORES
│
│
DAY 7-9: SCORE UPLOAD WINDOW                                      
──────────────────────────────────────────────────────────────────
│
│  ┌─────────────────────────────────────────────────────────┐
│  │  STEP 3: UPLOADER SUBMITS SCORES TO REPUTATION MANAGER  │
│  └─────────────────────────────────────────────────────────┘
│
│     scoreUploader calls reputationManager.uploadScores(
│         context: 0x8337...,
│         users:  [alice,  bob,   charlie, diana],
│         scores: [5000,   3000,  1500,    500  ]
│     )
│
│     scoreUploader calls reputationManager.finalizeContext(0x8337...)
│             ─► emit ContextFinalized { totalScore: 10,000 }
│
│     ┌──────────────────────────────────────┐
│     │  REPUTATION SCORES                   │
│     │  ────────────────────────────────    │
│     │  Alice:    5,000  (50%)              │
│     │  Bob:      3,000  (30%)              │
│     │  Charlie:  1,500  (15%)              │
│     │  Diana:      500  ( 5%)              │
│     │  ────────────────────────────────    │
│     │  TOTAL:   10,000  (100%)             │
│     └──────────────────────────────────────┘
│
│     Presale detects finalized scores
│             ─► emit ScoresUploaded { presaleId: 1, totalScore: 10,000 }
│             ─► Status: SCORES_UPLOADED
│
│
DAY 9: TOKEN DEPLOYMENT                                           
──────────────────────────────────────────────────────────────────
│
│  ┌─────────────────────────────────────────────────────────┐
│  │  STEP 4: PRESALE OWNER DEPLOYS TOKEN                    │
│  └─────────────────────────────────────────────────────────┘
│
│     REQUIREMENT: Status must be SCORES_UPLOADED
│     (scores must be finalized in ReputationManager before deployment)
│
│     presaleOwner calls presale.deployToken(presaleId, salt)
│
│     ┌─────────────────────────────────────────────────────────────────┐
│     │  HOW TOKEN DEPLOYMENT WORKS                                     │
│     │  ───────────────────────────────────────────────────────────    │
│     │                                                                 │
│     │  1. Presale calls Karma Factory to deploy new token             │
│     │                                                                 │
│     │  2. Factory mints 100,000,000,000 total tokens (100B)           │
│     │                                                                 │
│     │  3. Tokens are distributed based on extensionBps config:        │
│     │                                                                 │
│     │     ┌─────────────────────────────────────────────────────┐     │
│     │     │  TOTAL SUPPLY: 100,000,000,000 tokens               │     │
│     │     ├─────────────────────────────────────────────────────┤     │
│     │     │  Presale Extension (50%):  50,000,000,000 tokens    │     │
│     │     │  Liquidity Pool (50%):     50,000,000,000 tokens    │     │
│     │     └─────────────────────────────────────────────────────┘     │
│     │                                                                 │
│     │  4. Factory calls presale.receiveTokens() with 50B tokens       │
│     │     - Presale contract holds these tokens for participants      │
│     │     - Status changes to CLAIMABLE                               │
│     │                                                                 │
│     │  5. Remaining 50B tokens go to Uniswap V4 liquidity pool        │
│     │     - Paired with the contributed USDC                          │
│     │     - LP position locked in KarmaLpLocker                       │
│     │                                                                 │
│     └─────────────────────────────────────────────────────────────────┘
│
│             ─► Token created: 100,000,000,000 total tokens
│             ─► Presale receives: 50,000,000,000 tokens (extensionBps: 5000 = 50%)
│             ─► Liquidity pool receives: 50,000,000,000 tokens
│             ─► emit PresaleDeployed { presaleId: 1, token: 0xToken... }
│             ─► Status: CLAIMABLE
│             ─► lockupEndTime:  Day 9 + 7 days  = Day 16
│             ─► vestingEndTime: Day 16 + 30 days = Day 46
│
│     ┌─────────────────────────────────────────────────────────────────┐
│     │  ALLOCATION CALCULATION                                         │
│     │  ───────────────────────────────────────────────────────────    │
│     │                                                                 │
│     │  max_contribution = (user_score / total_score) × target_usdc   │
│     │  accepted = min(contributed, max_contribution)                  │
│     │  tokens = (accepted / total_accepted) × token_supply           │
│     │                                                                 │
│     │  ┌─────────┬───────┬─────────┬─────────────┬──────────┬───────┐│
│     │  │  User   │ Score │ Max     │ Contributed │ Accepted │Refund ││
│     │  ├─────────┼───────┼─────────┼─────────────┼──────────┼───────┤│
│     │  │ Alice   │ 5000  │ 50,000  │ 40,000      │ 40,000   │   0   ││
│     │  │ Bob     │ 3000  │ 30,000  │ 25,000      │ 25,000   │   0   ││
│     │  │ Charlie │ 1500  │ 15,000  │ 20,000      │ 15,000   │ 5,000 ││
│     │  │ Diana   │  500  │  5,000  │ 10,000      │  5,000   │ 5,000 ││
│     │  ├─────────┼───────┼─────────┼─────────────┼──────────┼───────┤│
│     │  │ TOTAL   │ 10000 │ 100,000 │ 95,000      │ 85,000   │10,000 ││
│     │  └─────────┴───────┴─────────┴─────────────┴──────────┴───────┘│
│     └─────────────────────────────────────────────────────────────────┘
│
│
DAY 9-16: LOCKUP PERIOD (tokens locked)                           
──────────────────────────────────────────────────────────────────
│
│     No claims allowed. Tokens are locked.
│
│
DAY 16: LOCKUP ENDS, VESTING BEGINS                               
──────────────────────────────────────────────────────────────────
│
│  ┌─────────────────────────────────────────────────────────┐
│  │  STEP 5: USERS CLAIM TOKENS (vesting starts)            │
│  └─────────────────────────────────────────────────────────┘
│
│     Vesting: 0% available at lockup end, increases linearly to 100%
│
│     alice   calls presale.claimTokens(presaleId)
│             ─► emit TokensClaimed { user: alice, tokenAmount: ... }
│
│     bob     calls presale.claimTokens(presaleId)
│             ─► emit TokensClaimed { user: bob, tokenAmount: ... }
│
│     charlie calls presale.claimTokens(presaleId)
│             ─► emit TokensClaimed { user: charlie, tokenAmount: ... }
│
│     diana   calls presale.claimTokens(presaleId)
│             ─► emit TokensClaimed { user: diana, tokenAmount: ... }
│
│
│  ┌─────────────────────────────────────────────────────────┐
│  │  STEP 6: PRESALE OWNER CLAIMS USDC                      │
│  └─────────────────────────────────────────────────────────┘
│
│     presaleOwner calls presale.claimUsdc(presaleId, presaleOwner)
│
│     ┌──────────────────────────────────────┐
│     │  USDC DISTRIBUTION                   │
│     │  ────────────────────────────────    │
│     │  Total Accepted:  85,000 USDC        │
│     │  Karma Fee (5%):   4,250 USDC        │
│     │  To Owner:        80,750 USDC        │
│     └──────────────────────────────────────┘
│
│             ─► emit UsdcClaimed { recipient: presaleOwner, amount: 80,750, fee: 4,250 }
│
│
│  ┌─────────────────────────────────────────────────────────┐
│  │  STEP 7: USERS CLAIM REFUNDS (if over-contributed)      │
│  └─────────────────────────────────────────────────────────┘
│
│     charlie calls presale.claimRefund(presaleId)
│             ─► emit RefundClaimed { user: charlie, refundAmount: 5,000 }
│
│     diana   calls presale.claimRefund(presaleId)
│             ─► emit RefundClaimed { user: diana, refundAmount: 5,000 }
│
│
DAY 16-46: VESTING PERIOD                                         
──────────────────────────────────────────────────────────────────
│
│     Users can claim more tokens as they vest linearly
│
│     Day 16:  0% vested
│     Day 31: 50% vested
│     Day 46: 100% vested
│
│
DAY 46: VESTING COMPLETE                                          
──────────────────────────────────────────────────────────────────
│
│     All tokens fully vested and claimable
│
│     ┌──────────────────────────────────────┐
│     │  FINAL TOKEN DISTRIBUTION            │
│     │  ────────────────────────────────    │
│     │  Alice:   23,529,411,764 tokens      │
│     │  Bob:     14,705,882,352 tokens      │
│     │  Charlie:  8,823,529,411 tokens      │
│     │  Diana:    2,941,176,470 tokens      │
│     └──────────────────────────────────────┘
│
│
════════════════════════════════════════════════════════════════════════════════════════════════════
                                      PRESALE COMPLETE
════════════════════════════════════════════════════════════════════════════════════════════════════
```

## Run Tests

```bash
forge test --match-test test_FullPresaleFlow -vv
```
