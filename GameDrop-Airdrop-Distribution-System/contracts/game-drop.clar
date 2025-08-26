;; GameDrop - Decentralized In-Game Airdrop Distribution System
;; Section 1: Core Infrastructure and Data Structures

(define-fungible-token game-token)

;; Constants and Error Codes
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-campaign-not-found (err u101))
(define-constant err-not-eligible (err u102))
(define-constant err-already-claimed (err u103))
(define-constant err-campaign-ended (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-invalid-multiplier (err u106))
(define-constant err-tier-not-found (err u107))
(define-constant err-invalid-bonus (err u108))
(define-constant err-referral-not-found (err u109))
(define-constant err-invalid-time-range (err u110))

;; Global State Variables
(define-data-var next-campaign-id uint u1)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points
(define-data-var total-platform-fees uint u0)
(define-data-var emergency-pause bool false)

;; Core Data Maps
(define-map airdrop-campaigns
  { campaign-id: uint }
  {
    campaign-name: (string-ascii 50),
    game-title: (string-ascii 50),
    creator: principal,
    total-budget: uint,
    reward-amount: uint,
    start-time: uint,
    end-time: uint,
    condition-type: (string-ascii 30),
    min-requirement: uint,
    total-claimed: uint,
    max-recipients: uint,
    is-active: bool,
    multiplier-active: bool,
    bonus-percentage: uint
  })

(define-map player-achievements
  { player: principal, campaign-id: uint }
  {
    achievement-value: uint,
    is-eligible: bool,
    claim-status: bool,
    verification-date: uint,
    tier-level: uint,
    bonus-earned: uint
  })

(define-map campaign-claims
  { campaign-id: uint, player: principal }
  { claimed-amount: uint, claim-date: uint, tier-bonus: uint })

(define-map leaderboard-positions
  { campaign-id: uint, player: principal }
  { position: uint, score: uint, last-updated: uint })

;; Extended Feature Maps
(define-map achievement-tiers
  { campaign-id: uint, tier: uint }
  { min-score: uint, multiplier: uint, tier-name: (string-ascii 20) })

(define-map campaign-stats
  { campaign-id: uint }
  { participants: uint, average-score: uint, highest-score: uint, completion-rate: uint })

(define-map referral-bonuses
  { referrer: principal, campaign-id: uint }
  { referred-count: uint, bonus-earned: uint, last-referral: uint })

(define-map daily-activity
  { player: principal, day: uint }
  { login-count: uint, achievements-submitted: uint, tokens-earned: uint })