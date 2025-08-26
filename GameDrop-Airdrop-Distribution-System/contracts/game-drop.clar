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

;; GameDrop - Section 3: Player Actions and Reward System

(define-public (submit-achievement (campaign-id uint) (achievement-value uint))
  (let 
    ((campaign-info (unwrap! (map-get? airdrop-campaigns { campaign-id: campaign-id }) err-campaign-not-found))
     (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
     (current-day (/ current-time u86400))
     (tier-info (calculate-tier campaign-id achievement-value))
     (stats (default-to { participants: u0, average-score: u0, highest-score: u0, completion-rate: u0 }
                         (map-get? campaign-stats { campaign-id: campaign-id }))))
    (begin
      (asserts! (not (var-get emergency-pause)) err-campaign-ended)
      (asserts! (get is-active campaign-info) err-campaign-ended)
      (asserts! (>= current-time (get start-time campaign-info)) err-campaign-ended)
      (asserts! (<= current-time (get end-time campaign-info)) err-campaign-ended)
      (asserts! (>= achievement-value (get min-requirement campaign-info)) err-not-eligible)
      
      (map-set player-achievements { player: tx-sender, campaign-id: campaign-id }
        {
          achievement-value: achievement-value,
          is-eligible: true,
          claim-status: false,
          verification-date: current-time,
          tier-level: tier-info,
          bonus-earned: u0
        })
      
      ;; Update daily activity
      (map-set daily-activity { player: tx-sender, day: current-day }
        (let ((daily-info (default-to { login-count: u0, achievements-submitted: u0, tokens-earned: u0 }
                                      (map-get? daily-activity { player: tx-sender, day: current-day }))))
          (merge daily-info { achievements-submitted: (+ (get achievements-submitted daily-info) u1) })))
      
      ;; Update campaign stats
      (map-set campaign-stats { campaign-id: campaign-id }
        { participants: (+ (get participants stats) u1),
          average-score: (/ (+ (* (get average-score stats) (get participants stats)) achievement-value) 
                           (+ (get participants stats) u1)),
          highest-score: (if (> achievement-value (get highest-score stats)) achievement-value (get highest-score stats)),
          completion-rate: (get completion-rate stats) })
      
      (ok true))))

(define-public (update-leaderboard-position (campaign-id uint) (player principal) (position uint) (score uint))
  (let ((campaign-info (unwrap! (map-get? airdrop-campaigns { campaign-id: campaign-id }) err-campaign-not-found)))
    (begin
      (asserts! (is-eq tx-sender (get creator campaign-info)) err-owner-only)
      
      (map-set leaderboard-positions { campaign-id: campaign-id, player: player }
        {
          position: position,
          score: score,
          last-updated: (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1)))
        })
      
      ;; Auto-qualify if position meets requirement
      (if (<= position (get min-requirement campaign-info))
        (map-set player-achievements { player: player, campaign-id: campaign-id }
          {
            achievement-value: score,
            is-eligible: true,
            claim-status: false,
            verification-date: (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))),
            tier-level: (calculate-tier campaign-id score),
            bonus-earned: u0
          })
        true)
      
      (ok true))))

(define-public (claim-airdrop (campaign-id uint))
  (let 
    ((campaign-info (unwrap! (map-get? airdrop-campaigns { campaign-id: campaign-id }) err-campaign-not-found))
     (player-info (unwrap! (map-get? player-achievements { player: tx-sender, campaign-id: campaign-id }) err-not-eligible))
     (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
     (current-day (/ current-time u86400))
     (base-reward (get reward-amount campaign-info))
     (tier-multiplier (get-tier-multiplier campaign-id (get tier-level player-info)))
     (platform-fee (/ (* base-reward (var-get platform-fee-rate)) u10000))
     (final-reward (- (* base-reward tier-multiplier) platform-fee)))
    (begin
      (asserts! (not (var-get emergency-pause)) err-campaign-ended)
      (asserts! (get is-eligible player-info) err-not-eligible)
      (asserts! (not (get claim-status player-info)) err-already-claimed)
      (asserts! (< (get total-claimed campaign-info) (get max-recipients campaign-info)) err-campaign-ended)
      (asserts! (> current-time (get end-time campaign-info)) err-campaign-ended)
      
      ;; Transfer tokens from campaign creator to claimant
      (try! (ft-transfer? game-token final-reward (get creator campaign-info) tx-sender))
      
      ;; Collect platform fee
      (try! (ft-transfer? game-token platform-fee (get creator campaign-info) contract-owner))
      (var-set total-platform-fees (+ (var-get total-platform-fees) platform-fee))
      
      ;; Update claim status
      (map-set player-achievements { player: tx-sender, campaign-id: campaign-id }
        (merge player-info { claim-status: true, bonus-earned: (- final-reward base-reward) }))
      
      ;; Record claim
      (map-set campaign-claims { campaign-id: campaign-id, player: tx-sender }
        { claimed-amount: final-reward, claim-date: current-time, tier-bonus: (- final-reward base-reward) })
      
      ;; Update campaign stats
      (map-set airdrop-campaigns { campaign-id: campaign-id }
        (merge campaign-info { total-claimed: (+ (get total-claimed campaign-info) u1) }))
      
      ;; Update daily activity
      (map-set daily-activity { player: tx-sender, day: current-day }
        (let ((daily-info (default-to { login-count: u0, achievements-submitted: u0, tokens-earned: u0 }
                                      (map-get? daily-activity { player: tx-sender, day: current-day }))))
          (merge daily-info { tokens-earned: (+ (get tokens-earned daily-info) final-reward) })))
      
      (ok final-reward))))

(define-public (submit-referral (campaign-id uint) (referred-player principal))
  (let ((campaign-info (unwrap! (map-get? airdrop-campaigns { campaign-id: campaign-id }) err-campaign-not-found))
        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        (referral-info (default-to { referred-count: u0, bonus-earned: u0, last-referral: u0 }
                                   (map-get? referral-bonuses { referrer: tx-sender, campaign-id: campaign-id }))))
    (begin
      (asserts! (get is-active campaign-info) err-campaign-ended)
      
      (map-set referral-bonuses { referrer: tx-sender, campaign-id: campaign-id }
        { referred-count: (+ (get referred-count referral-info) u1),
          bonus-earned: (get bonus-earned referral-info),
          last-referral: current-time })
      
      ;; Award referral bonus (5% of base reward)
      (let ((referral-bonus (/ (get reward-amount campaign-info) u20)))
        (try! (ft-mint? game-token referral-bonus tx-sender))
        (map-set referral-bonuses { referrer: tx-sender, campaign-id: campaign-id }
          (merge (unwrap-panic (map-get? referral-bonuses { referrer: tx-sender, campaign-id: campaign-id }))
                 { bonus-earned: (+ (get bonus-earned referral-info) referral-bonus) })))
      
      (ok true))))

;; GameDrop - Section 4: Utility Functions and Data Access

(define-public (batch-update-achievements (campaign-id uint) (players (list 50 principal)) (scores (list 50 uint)))
  (let ((campaign-info (unwrap! (map-get? airdrop-campaigns { campaign-id: campaign-id }) err-campaign-not-found)))
    (begin
      (asserts! (is-eq tx-sender (get creator campaign-info)) err-owner-only)
      (asserts! (is-eq (len players) (len scores)) err-not-eligible)
      
      (fold batch-update-fold 
            (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 
                  u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49)
            { campaign-id: campaign-id, players: players, scores: scores, index: u0 })
      (ok true))))

(define-private (batch-update-fold 
  (counter uint) 
  (acc { campaign-id: uint, players: (list 50 principal), scores: (list 50 uint), index: uint }))
  (let ((current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        (current-index counter)
        (campaign-id (get campaign-id acc)))
    (if (< current-index (len (get players acc)))
      (let ((player (unwrap-panic (element-at (get players acc) current-index)))
            (score (unwrap-panic (element-at (get scores acc) current-index))))
        (begin
          (map-set player-achievements { player: player, campaign-id: campaign-id }
            {
              achievement-value: score,
              is-eligible: true,
              claim-status: false,
              verification-date: current-time,
              tier-level: (calculate-tier campaign-id score),
              bonus-earned: u0
            })
          acc))
      acc)))

;; Helper Functions
(define-private (calculate-tier (campaign-id uint) (score uint))
  (if (is-some (map-get? achievement-tiers { campaign-id: campaign-id, tier: u3 }))
    (if (>= score (get min-score (unwrap-panic (map-get? achievement-tiers { campaign-id: campaign-id, tier: u3 })))) u3
    (if (is-some (map-get? achievement-tiers { campaign-id: campaign-id, tier: u2 }))
      (if (>= score (get min-score (unwrap-panic (map-get? achievement-tiers { campaign-id: campaign-id, tier: u2 })))) u2
      (if (is-some (map-get? achievement-tiers { campaign-id: campaign-id, tier: u1 }))
        (if (>= score (get min-score (unwrap-panic (map-get? achievement-tiers { campaign-id: campaign-id, tier: u1 })))) u1 u0)
        u0))
      u0))
    u0))

(define-private (get-tier-multiplier (campaign-id uint) (tier-level uint))
  (match (map-get? achievement-tiers { campaign-id: campaign-id, tier: tier-level })
    tier-info (/ (get multiplier tier-info) u100)
    u1))

;; Read-Only Functions
(define-read-only (get-campaign-info (campaign-id uint))
  (map-get? airdrop-campaigns { campaign-id: campaign-id }))

(define-read-only (get-player-achievement (player principal) (campaign-id uint))
  (map-get? player-achievements { player: player, campaign-id: campaign-id }))

(define-read-only (get-leaderboard-position (campaign-id uint) (player principal))
  (map-get? leaderboard-positions { campaign-id: campaign-id, player: player }))

(define-read-only (get-claim-info (campaign-id uint) (player principal))
  (map-get? campaign-claims { campaign-id: campaign-id, player: player }))

(define-read-only (get-token-balance (user principal))
  (ft-get-balance game-token user))

(define-read-only (get-achievement-tier (campaign-id uint) (tier uint))
  (map-get? achievement-tiers { campaign-id: campaign-id, tier: tier }))

(define-read-only (get-campaign-stats (campaign-id uint))
  (map-get? campaign-stats { campaign-id: campaign-id }))

(define-read-only (get-referral-info (referrer principal) (campaign-id uint))
  (map-get? referral-bonuses { referrer: referrer, campaign-id: campaign-id }))

(define-read-only (get-daily-activity (player principal) (day uint))
  (map-get? daily-activity { player: player, day: day }))

(define-read-only (get-platform-stats)
  { total-campaigns: (var-get next-campaign-id),
    total-fees-collected: (var-get total-platform-fees),
    current-fee-rate: (var-get platform-fee-rate),
    emergency-paused: (var-get emergency-pause) })

(define-read-only (calculate-potential-reward (campaign-id uint) (player principal))
  (match (map-get? player-achievements { player: player, campaign-id: campaign-id })
    player-info 
      (let ((campaign-info (unwrap-panic (map-get? airdrop-campaigns { campaign-id: campaign-id })))
            (base-reward (get reward-amount campaign-info))
            (tier-multiplier (get-tier-multiplier campaign-id (get tier-level player-info)))
            (platform-fee (/ (* base-reward (var-get platform-fee-rate)) u10000)))
        (some (- (* base-reward tier-multiplier) platform-fee)))
    none))

(define-read-only (get-campaign-leaderboard (campaign-id uint))
  ;; This would typically return a list of top players, but Clarity limitations prevent complex queries
  ;; In a real implementation, this would require off-chain indexing
  (ok "Use off-chain indexing for leaderboard data"))