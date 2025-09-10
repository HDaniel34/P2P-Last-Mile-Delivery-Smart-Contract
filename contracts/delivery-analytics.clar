(define-constant err-stats-not-found (err u300))
(define-constant err-invalid-performance (err u301))
(define-constant err-badge-not-earned (err u302))

(define-constant bronze-threshold u10)
(define-constant silver-threshold u25)
(define-constant gold-threshold u50)
(define-constant diamond-threshold u100)

(define-map deliverer-stats
  { deliverer: principal }
  {
    total-deliveries: uint,
    successful-deliveries: uint,
    disputed-deliveries: uint,
    average-rating: uint,
    total-earned: uint,
    streak-count: uint,
    last-delivery-block: uint
  }
)

(define-map performance-badges
  { deliverer: principal, badge-type: (string-ascii 10) }
  { earned-at: uint, active: bool }
)

(define-map leaderboard-rankings
  { rank: uint }
  { deliverer: principal, performance-score: uint }
)

(define-data-var leaderboard-size uint u10)

(define-public (update-delivery-stats (deliverer principal) (successful bool) (rating uint) (reward-earned uint))
  (let (
    (current-stats (default-to 
      { total-deliveries: u0, successful-deliveries: u0, disputed-deliveries: u0, 
        average-rating: u0, total-earned: u0, streak-count: u0, last-delivery-block: u0 }
      (map-get? deliverer-stats { deliverer: deliverer })))
    (new-total (+ (get total-deliveries current-stats) u1))
    (new-successful (if successful (+ (get successful-deliveries current-stats) u1) (get successful-deliveries current-stats)))
    (new-disputed (if successful (get disputed-deliveries current-stats) (+ (get disputed-deliveries current-stats) u1)))
    (new-rating (if (> rating u0) (/ (+ (* (get average-rating current-stats) (get total-deliveries current-stats)) rating) new-total) (get average-rating current-stats)))
    (new-earned (+ (get total-earned current-stats) reward-earned))
    (streak-broken (> (- stacks-block-height (get last-delivery-block current-stats)) u288))
    (new-streak (if (and successful (not streak-broken)) (+ (get streak-count current-stats) u1) (if successful u1 u0)))
  )
    (map-set deliverer-stats
      { deliverer: deliverer }
      {
        total-deliveries: new-total,
        successful-deliveries: new-successful,
        disputed-deliveries: new-disputed,
        average-rating: new-rating,
        total-earned: new-earned,
        streak-count: new-streak,
        last-delivery-block: stacks-block-height
      }
    )
    (check-and-award-badges deliverer new-total new-streak)
    (update-leaderboard deliverer)
  )
)

(define-private (check-and-award-badges (deliverer principal) (total-deliveries uint) (streak-count uint))
  (begin
    (and (>= total-deliveries bronze-threshold)
      (map-set performance-badges { deliverer: deliverer, badge-type: "bronze" } { earned-at: stacks-block-height, active: true }))
    (and (>= total-deliveries silver-threshold)
      (map-set performance-badges { deliverer: deliverer, badge-type: "silver" } { earned-at: stacks-block-height, active: true }))
    (and (>= total-deliveries gold-threshold)
      (map-set performance-badges { deliverer: deliverer, badge-type: "gold" } { earned-at: stacks-block-height, active: true }))
    (and (>= total-deliveries diamond-threshold)
      (map-set performance-badges { deliverer: deliverer, badge-type: "diamond" } { earned-at: stacks-block-height, active: true }))
    (and (>= streak-count u20)
      (map-set performance-badges { deliverer: deliverer, badge-type: "streak" } { earned-at: stacks-block-height, active: true }))
    true
  )
)

(define-private (update-leaderboard (deliverer principal))
  (let (
    (stats (unwrap! (map-get? deliverer-stats { deliverer: deliverer }) err-stats-not-found))
    (performance-score (calculate-performance-score stats))
  )
    (map-set leaderboard-rankings { rank: u1 } { deliverer: deliverer, performance-score: performance-score })
    (ok true)
  )
)

(define-read-only (calculate-performance-score (stats { total-deliveries: uint, successful-deliveries: uint, disputed-deliveries: uint, average-rating: uint, total-earned: uint, streak-count: uint, last-delivery-block: uint }))
  (let (
    (success-rate (if (> (get total-deliveries stats) u0) (/ (* (get successful-deliveries stats) u100) (get total-deliveries stats)) u0))
    (streak-bonus (if (> (get streak-count stats) u10) (* (get streak-count stats) u5) u0))
    (rating-bonus (* (get average-rating stats) u10))
  )
    (+ success-rate streak-bonus rating-bonus)
  )
)

(define-read-only (get-deliverer-stats (deliverer principal))
  (map-get? deliverer-stats { deliverer: deliverer })
)

(define-read-only (get-performance-badge (deliverer principal) (badge-type (string-ascii 10)))
  (map-get? performance-badges { deliverer: deliverer, badge-type: badge-type })
)

(define-read-only (get-bonus-multiplier (deliverer principal))
  (let (
    (has-diamond (is-some (map-get? performance-badges { deliverer: deliverer, badge-type: "diamond" })))
    (has-gold (is-some (map-get? performance-badges { deliverer: deliverer, badge-type: "gold" })))
    (has-silver (is-some (map-get? performance-badges { deliverer: deliverer, badge-type: "silver" })))
    (has-streak (is-some (map-get? performance-badges { deliverer: deliverer, badge-type: "streak" })))
  )
    (if has-diamond u150
      (if has-gold u125
        (if has-silver u110
          (if has-streak u105 u100))))
  )
)

(define-read-only (get-leaderboard-entry (rank uint))
  (map-get? leaderboard-rankings { rank: rank })
)
