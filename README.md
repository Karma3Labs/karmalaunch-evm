# Karma Reputation Presale

A presale extension where reputation scores determine max contribution amounts **only when oversubscribed**.

## Behavior

| Scenario | Behavior |
|----------|----------|
| Under `minUsdc` raised | Presale fails, users can claim full refunds |
| Under `targetUsdc` raised | No caps applied, all contributions accepted |
| Above `targetUsdc` raised | Reputation-based caps applied, excess refunded |

## Score Mapping (when caps apply)

- `SCORE_MIN`: 1,000
- `SCORE_MAX`: 10,000
- `SCORE_DEFAULT`: 500 (for users with no reputation)

## Formula (when oversubscribed)

```
max_contribution = (user_score / total_score) × target_usdc
accepted = min(contributed, max_contribution)
tokens = (accepted / total_accepted) × token_supply
```

---

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
│     alice   calls presale.contribute(50,000 USDC)
│             ─► emit Contribution { contributor: alice, amount: 50,000, totalRaised: 50,000 }
│
│     bob     calls presale.contribute(30,000 USDC)
│             ─► emit Contribution { contributor: bob, amount: 30,000, totalRaised: 80,000 }
│
│     charlie calls presale.contribute(25,000 USDC)
│             ─► emit Contribution { contributor: charlie, amount: 25,000, totalRaised: 105,000 }
│
│     diana   calls presale.contribute(15,000 USDC)
│             ─► emit Contribution { contributor: diana, amount: 15,000, totalRaised: 120,000 }
│
│     ┌──────────────────────────────────────┐
│     │  CONTRIBUTIONS SUMMARY               │
│     │  ────────────────────────────────    │
│     │  Alice:    50,000 USDC               │
│     │  Bob:      30,000 USDC               │
│     │  Charlie:  25,000 USDC               │
│     │  Diana:    15,000 USDC               │
│     │  ────────────────────────────────    │
│     │  TOTAL:   120,000 USDC               │
│     │  TARGET:  100,000 USDC               │
│     │  STATUS:  OVERSUBSCRIBED! ⚠️          │
│     └──────────────────────────────────────┘
│
│
DAY 7: CONTRIBUTION WINDOW ENDS                                   
──────────────────────────────────────────────────────────────────
│
│     totalContributions (120,000) >= minUsdc (50,000) ?
│     YES ─► Status: PENDING_SCORES
│
│     totalContributions (120,000) > targetUsdc (100,000) ?
│     YES ─► Reputation caps will apply!
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
│     │  ALLOCATION CALCULATION (OVERSUBSCRIBED CASE)                   │
│     │  ───────────────────────────────────────────────────────────    │
│     │                                                                 │
│     │  Since totalContributions (120k) > targetUsdc (100k),           │
│     │  reputation-based caps are applied:                             │
│     │                                                                 │
│     │  max_contribution = (user_score / total_score) × target_usdc    │
│     │  accepted = min(contributed, max_contribution)                  │
│     │  refund = contributed - accepted                                │
│     │  tokens = (accepted / target_usdc) × token_supply               │
│     │                                                                 │
│     │  ┌─────────┬───────┬─────────┬─────────────┬──────────┬────────┐│
│     │  │  User   │ Score │ Max     │ Contributed │ Accepted │ Refund ││
│     │  ├─────────┼───────┼─────────┼─────────────┼──────────┼────────┤│
│     │  │ Alice   │ 5000  │ 50,000  │ 50,000      │ 50,000   │   0    ││
│     │  │ Bob     │ 3000  │ 30,000  │ 30,000      │ 30,000   │   0    ││
│     │  │ Charlie │ 1500  │ 15,000  │ 25,000      │ 15,000   │ 10,000 ││
│     │  │ Diana   │  500  │  5,000  │ 15,000      │  5,000   │ 10,000 ││
│     │  ├─────────┼───────┼─────────┼─────────────┼──────────┼────────┤│
│     │  │ TOTAL   │ 10000 │ 100,000 │ 120,000     │ 100,000  │ 20,000 ││
│     │  └─────────┴───────┴─────────┴─────────────┴──────────┴────────┘│
│     │                                                                 │
│     │  NOTE: If totalContributions <= targetUsdc, NO caps apply!      │
│     │        All contributions would be accepted in full.             │
│     │                                                                 │
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
│     │  Total Accepted: 100,000 USDC        │
│     │  Karma Fee (5%):   5,000 USDC        │
│     │  To Owner:        95,000 USDC        │
│     └──────────────────────────────────────┘
│
│             ─► emit UsdcClaimed { recipient: presaleOwner, amount: 95,000, fee: 5,000 }
│
│
│  ┌─────────────────────────────────────────────────────────┐
│  │  STEP 7: USERS CLAIM REFUNDS (if over-contributed)      │
│  └─────────────────────────────────────────────────────────┘
│
│     charlie calls presale.claimRefund(presaleId)
│             ─► emit RefundClaimed { user: charlie, refundAmount: 10,000 }
│
│     diana   calls presale.claimRefund(presaleId)
│             ─► emit RefundClaimed { user: diana, refundAmount: 10,000 }
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
│     │  Alice:   25,000,000,000 tokens (50%)│
│     │  Bob:     15,000,000,000 tokens (30%)│
│     │  Charlie:  7,500,000,000 tokens (15%)│
│     │  Diana:    2,500,000,000 tokens  (5%)│
│     └──────────────────────────────────────┘
│
│
════════════════════════════════════════════════════════════════════════════════════════════════════
                                      PRESALE COMPLETE
════════════════════════════════════════════════════════════════════════════════════════════════════
```

---

## Undersubscribed Example

When `totalContributions <= targetUsdc`, **no reputation caps apply**:

```
┌─────────────────────────────────────────────────────────────────┐
│  UNDERSUBSCRIBED CASE (no caps)                                 │
│  ───────────────────────────────────────────────────────────    │
│                                                                 │
│  targetUsdc: 100,000 USDC                                       │
│  totalContributions: 80,000 USDC                                │
│                                                                 │
│  Since 80,000 <= 100,000, ALL contributions accepted as-is:     │
│                                                                 │
│  ┌─────────┬─────────────┬──────────┬────────┐                  │
│  │  User   │ Contributed │ Accepted │ Refund │                  │
│  ├─────────┼─────────────┼──────────┼────────┤                  │
│  │ Alice   │ 40,000      │ 40,000   │   0    │                  │
│  │ Bob     │ 25,000      │ 25,000   │   0    │                  │
│  │ Charlie │ 10,000      │ 10,000   │   0    │                  │
│  │ Diana   │  5,000      │  5,000   │   0    │                  │
│  ├─────────┼─────────────┼──────────┼────────┤                  │
│  │ TOTAL   │ 80,000      │ 80,000   │   0    │                  │
│  └─────────┴─────────────┴──────────┴────────┘                  │
│                                                                 │
│  Token allocation: (accepted / totalContributions) × supply     │
│  Everyone gets tokens proportional to their contribution.       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Run Tests

```bash
forge test --match-test test_FullPresaleFlow -vv
```
