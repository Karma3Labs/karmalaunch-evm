# Presale Math (Oversubscribed Case)

When `totalContributions > targetUsdc`, reputation-based allocation applies.

---

## V1: Proportional Caps

Each user gets a max contribution proportional to their score share.

### Formula

```
maxContribution = (userScore / totalScore) × targetUsdc
accepted = min(contributed, maxContribution)
refund = contributed - accepted
tokens = (accepted / targetUsdc) × tokenSupply
```

### Example

```
targetUsdc  = 100,000 USDC
totalScore  = 10,000
tokenSupply = 50,000,000,000
```

| User    | Score | Contributed | Max Cap | Accepted | Refund | Tokens |
|---------|-------|-------------|---------|----------|--------|--------|
| Alice   | 5,000 | 50,000      | 50,000  | 50,000   | 0      | 25B    |
| Bob     | 3,000 | 30,000      | 30,000  | 30,000   | 0      | 15B    |
| Charlie | 1,500 | 25,000      | 15,000  | 15,000   | 10,000 | 7.5B   |
| Diana   | 500   | 15,000      | 5,000   | 5,000    | 10,000 | 2.5B   |
| **Total** | **10,000** | **120,000** | **100,000** | **100,000** | **20,000** | **50B** |

---

## V2: Priority Allocation

Users are sorted by reputation (highest first). Full contributions are accepted until target is reached.

### Algorithm

```
1. Sort users by score (descending)
   - Users with same score: random order
   - Users with no reputation (score = 0): handled last
2. For each user (highest score first):
   - If cumulative + contribution <= target: accept full contribution
   - If cumulative < target < cumulative + contribution: accept partial (target - cumulative)
   - If cumulative >= target: accept nothing (full refund)
3. tokens = (accepted / totalAccepted) × tokenSupply
```

### Example

```
targetUsdc  = 100,000 USDC
tokenSupply = 50,000,000,000
```

| Priority | User    | Score | Contributed | Cumulative | Accepted | Refund | Tokens |
|----------|---------|-------|-------------|------------|----------|--------|--------|
| 1        | Alice   | 5,000 | 50,000      | 50,000     | 50,000   | 0      | 25B    |
| 2        | Bob     | 3,000 | 30,000      | 80,000     | 30,000   | 0      | 15B    |
| 3        | Charlie | 1,500 | 25,000      | 100,000    | 20,000   | 5,000  | 10B    |
| 4        | Diana   | 500   | 15,000      | 100,000    | 0        | 15,000 | 0      |
| **Total** |         |       | **120,000** |            | **100,000** | **20,000** | **50B** |

### Key Difference from V1

- **V1**: Everyone with sufficient reputation gets *some* allocation
- **V2**: Highest reputation users get *full* allocation, lowest may get *nothing*