# GameDrop Airdrop Distribution System

A decentralized platform for automated in-game reward distribution based on player achievements, leaderboard positions, and event participation.

## Features

- **Automated Airdrops**: Smart contract-based reward distribution
- **Achievement Verification**: On-chain verification of player accomplishments
- **Leaderboard Integration**: Position-based reward qualification
- **Campaign Management**: Create time-limited airdrop campaigns
- **Token Distribution**: Fungible token rewards for achievements
- **Anti-Gaming Protection**: Prevent duplicate claims and manipulation

## Supported Condition Types

- **Leaderboard Position**: Top N players receive rewards
- **Score Threshold**: Players above minimum score qualify
- **Event Participation**: Participation in specific game events
- **Achievement Unlocks**: Completion of specific in-game milestones
- **Time-based Challenges**: Limited-time event completion
- **Community Goals**: Collective achievement rewards

## Smart Contract Functions

### Public Functions
- `create-airdrop-campaign`: Launch new reward distribution campaign
- `submit-achievement`: Players submit achievement data for verification
- `update-leaderboard-position`: Game developers update player rankings
- `claim-airdrop`: Eligible players claim their token rewards
- `end-campaign`: Campaign creator deactivates distribution

### Read-Only Functions
- `get-campaign-info`: Retrieve detailed campaign information
- `get-player-achievement`: Check player's achievement status
- `get-leaderboard-position`: View player's ranking and score
- `get-claim-info`: Verify claim history and amounts
- `get-token-balance`: Check user's token balance

## Campaign Workflow

1. **Campaign Creation**: Developers create airdrop with conditions
2. **Budget Allocation**: Tokens minted and allocated to campaign
3. **Achievement Submission**: Players submit qualifying achievements
4. **Verification**: Automated verification against conditions
5. **Claim Period**: Eligible players claim rewards after campaign ends
6. **Distribution**: Automatic token transfer to verified players

## Use Cases

### For Game Developers
- **Player Retention**: Incentivize continued gameplay
- **Event Promotion**: Drive participation in special events
- **Community Building**: Reward top contributors and players
- **Marketing Campaigns**: Token-based promotional activities
- **Fair Distribution**: Transparent, automated reward systems

### For Players
- **Achievement Rewards**: Earn tokens for gameplay milestones
- **Competitive Benefits**: Rewards for leaderboard performance
- **Event Participation**: Tokens for joining special events
- **Skill Recognition**: Compensation for demonstrated abilities
- **Community Contribution**: Rewards for helping other players

## Benefits

- **Transparency**: All rewards and conditions visible on blockchain
- **Automation**: No manual intervention required for distribution
- **Anti-Fraud**: Prevents duplicate claims and manipulation
- **Cross-Game**: Tokens can be used across multiple games
- **Verifiable**: Player achievements cryptographically verified

## Integration Examples

```javascript
// Check if player qualifies for airdrop
const isEligible = await contract.getPlayerAchievement(playerAddress, campaignId);

// Submit leaderboard position
await contract.updateLeaderboardPosition(campaignId, playerAddress, position, score);

// Claim rewards
await contract.claimAirdrop(campaignId);