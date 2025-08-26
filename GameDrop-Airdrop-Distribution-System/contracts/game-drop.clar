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

;; GameDrop - Section 2: Campaign Management Functions

(define-public (create-airdrop-campaign
  (campaign-name (string-ascii 50))
  (game-title (string-ascii 50))
  (total-budget uint)
  (reward-amount uint)
  (start-time uint)
  (end-time uint)
  (condition-type (string-ascii 30))
  (min-requirement uint)
  (max-recipients uint)
  (bonus-percentage uint))
  (let ((campaign-id (var-get next-campaign-id)))
    (begin
      (asserts! (not (var-get emergency-pause)) err-campaign-ended)
      (asserts! (< start-time end-time) err-invalid-time-range)
      (asserts! (>= total-budget (* reward-amount max-recipients)) err-insufficient-funds)
      (asserts! (<= bonus-percentage u5000) err-invalid-bonus) ;; Max 50% bonus
      (try! (ft-mint? game-token total-budget tx-sender))
      
      (map-set airdrop-campaigns { campaign-id: campaign-id }
        {
          campaign-name: campaign-name,
          game-title: game-title,
          creator: tx-sender,
          total-budget: total-budget,
          reward-amount: reward-amount,
          start-time: start-time,
          end-time: end-time,
          condition-type: condition-type,
          min-requirement: min-requirement,
          total-claimed: u0,
          max-recipients: max-recipients,
          is-active: true,
          multiplier-active: false,
          bonus-percentage: bonus-percentage
        })
      
      (map-set campaign-stats { campaign-id: campaign-id }
        { participants: u0, average-score: u0, highest-score: u0, completion-rate: u0 })
      
      (var-set next-campaign-id (+ campaign-id u1))
      (ok campaign-id))))

(define-public (create-achievement-tier 
  (campaign-id uint) 
  (tier uint) 
  (min-score uint) 
  (multiplier uint) 
  (tier-name (string-ascii 20)))
  (let ((campaign-info (unwrap! (map-get? airdrop-campaigns { campaign-id: campaign-id }) err-campaign-not-found)))
    (begin
      (asserts! (is-eq tx-sender (get creator campaign-info)) err-owner-only)
      (asserts! (and (>= multiplier u100) (<= multiplier u500)) err-invalid-multiplier) ;; 1x to 5x multiplier
      
      (map-set achievement-tiers { campaign-id: campaign-id, tier: tier }
        { min-score: min-score, multiplier: multiplier, tier-name: tier-name })
      
      (map-set airdrop-campaigns { campaign-id: campaign-id }
        (merge campaign-info { multiplier-active: true }))
      
      (ok true))))

(define-public (end-campaign (campaign-id uint))
  (let ((campaign-info (unwrap! (map-get? airdrop-campaigns { campaign-id: campaign-id }) err-campaign-not-found)))
    (begin
      (asserts! (is-eq tx-sender (get creator campaign-info)) err-owner-only)
      (map-set airdrop-campaigns { campaign-id: campaign-id }
        (merge campaign-info { is-active: false }))
      
      ;; Calculate final completion rate
      (let ((stats (unwrap-panic (map-get? campaign-stats { campaign-id: campaign-id }))))
        (map-set campaign-stats { campaign-id: campaign-id }
          (merge stats { completion-rate: (/ (* (get total-claimed campaign-info) u100) (get participants stats)) })))
      
      (ok true))))

(define-public (emergency-pause-toggle)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set emergency-pause (not (var-get emergency-pause)))
    (ok (var-get emergency-pause))))

(define-public (update-platform-fee (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-multiplier) ;; Max 10% fee
    (var-set platform-fee-rate new-rate)
    (ok new-rate)))