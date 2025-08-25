;; Records Retention Scheduling Contract
;; Automates document archiving and disposal according to legal requirements

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-SCHEDULE-NOT-FOUND (err u401))
(define-constant ERR-DOCUMENT-NOT-FOUND (err u402))
(define-constant ERR-INVALID-RETENTION-PERIOD (err u403))
(define-constant ERR-SCHEDULE-EXISTS (err u404))
(define-constant ERR-CANNOT-DISPOSE (err u405))

;; Retention Actions
(define-constant ACTION-RETAIN u1)
(define-constant ACTION-ARCHIVE u2)
(define-constant ACTION-DISPOSE u3)
(define-constant ACTION-REVIEW u4)

;; Document Types
(define-constant TYPE-ADMINISTRATIVE u1)
(define-constant TYPE-FINANCIAL u2)
(define-constant TYPE-LEGAL u3)
(define-constant TYPE-PERSONNEL u4)
(define-constant TYPE-OPERATIONAL u5)

;; Data Variables
(define-data-var disposal-enabled bool false)
(define-data-var next-schedule-id uint u1)
(define-data-var next-disposal-id uint u1)

;; Data Maps
(define-map retention-schedules
  { schedule-id: uint }
  {
    schedule-name: (string-ascii 100),
    document-type: uint,
    department: (string-ascii 100),
    retention-period-blocks: uint,
    archive-period-blocks: uint,
    disposal-method: (string-ascii 50),
    legal-authority: (string-ascii 200),
    is-active: bool,
    created-by: principal,
    created-at: uint
  }
)

(define-map document-retention
  { document-id: (string-ascii 64) }
  {
    schedule-id: uint,
    retention-start: uint,
    retention-end: uint,
    archive-date: uint,
    disposal-date: uint,
    current-action: uint,
    last-review: uint,
    hold-status: bool,
    hold-reason: (optional (string-ascii 200))
  }
)

(define-map disposal-records
  { disposal-id: uint }
  {
    document-id: (string-ascii 64),
    disposed-at: uint,
    disposed-by: principal,
    disposal-method: (string-ascii 50),
    disposal-reason: (string-ascii 200),
    witness: (optional principal),
    certificate-hash: (optional (buff 32))
  }
)

(define-map legal-holds
  { hold-id: uint }
  {
    document-ids: (list 50 (string-ascii 64)),
    hold-reason: (string-ascii 500),
    initiated-by: principal,
    initiated-at: uint,
    expected-end: (optional uint),
    is-active: bool
  }
)

(define-map authorized-disposers
  { disposer: principal }
  { is-authorized: bool, department: (string-ascii 100) }
)

;; Data Variables for counters
(define-data-var next-hold-id uint u1)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-disposer)
  (default-to false
    (get is-authorized
      (map-get? authorized-disposers { disposer: tx-sender })
    )
  )
)

(define-private (is-valid-document-type (doc-type uint))
  (and (>= doc-type u1) (<= doc-type u5))
)

(define-private (is-valid-action (action uint))
  (and (>= action u1) (<= action u4))
)

;; Public Functions

;; Authorize disposer
(define-public (authorize-disposer (disposer principal) (department (string-ascii 100)))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-disposers
      { disposer: disposer }
      { is-authorized: true, department: department }
    ))
  )
)

;; Enable/disable disposal
(define-public (set-disposal-enabled (enabled bool))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set disposal-enabled enabled))
  )
)

;; Create retention schedule
(define-public (create-retention-schedule
  (schedule-name (string-ascii 100))
  (document-type uint)
  (department (string-ascii 100))
  (retention-period-blocks uint)
  (archive-period-blocks uint)
  (disposal-method (string-ascii 50))
  (legal-authority (string-ascii 200))
)
  (let
    (
      (schedule-id (var-get next-schedule-id))
    )
    (asserts! (is-authorized-disposer) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-document-type document-type) ERR-INVALID-RETENTION-PERIOD)
    (asserts! (> retention-period-blocks u0) ERR-INVALID-RETENTION-PERIOD)
    (asserts! (> archive-period-blocks u0) ERR-INVALID-RETENTION-PERIOD)

    (map-set retention-schedules
      { schedule-id: schedule-id }
      {
        schedule-name: schedule-name,
        document-type: document-type,
        department: department,
        retention-period-blocks: retention-period-blocks,
        archive-period-blocks: archive-period-blocks,
        disposal-method: disposal-method,
        legal-authority: legal-authority,
        is-active: true,
        created-by: tx-sender,
        created-at: block-height
      }
    )

    (var-set next-schedule-id (+ schedule-id u1))
    (ok schedule-id)
  )
)

;; Apply retention schedule to document
(define-public (apply-retention-schedule (document-id (string-ascii 64)) (schedule-id uint))
  (let
    (
      (schedule (unwrap! (map-get? retention-schedules { schedule-id: schedule-id }) ERR-SCHEDULE-NOT-FOUND))
      (retention-end (+ block-height (get retention-period-blocks schedule)))
      (archive-date (+ retention-end (get archive-period-blocks schedule)))
      (disposal-date (+ archive-date u1440)) ;; Additional 10 days before disposal
    )
    (asserts! (is-authorized-disposer) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active schedule) ERR-SCHEDULE-NOT-FOUND)

    (ok (map-set document-retention
      { document-id: document-id }
      {
        schedule-id: schedule-id,
        retention-start: block-height,
        retention-end: retention-end,
        archive-date: archive-date,
        disposal-date: disposal-date,
        current-action: ACTION-RETAIN,
        last-review: block-height,
        hold-status: false,
        hold-reason: none
      }
    ))
  )
)

;; Update document retention action
(define-public (update-retention-action (document-id (string-ascii 64)) (new-action uint))
  (let
    (
      (retention-data (unwrap! (map-get? document-retention { document-id: document-id }) ERR-DOCUMENT-NOT-FOUND))
    )
    (asserts! (is-authorized-disposer) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-action new-action) ERR-INVALID-RETENTION-PERIOD)
    (asserts! (not (get hold-status retention-data)) ERR-CANNOT-DISPOSE)

    (ok (map-set document-retention
      { document-id: document-id }
      (merge retention-data {
        current-action: new-action,
        last-review: block-height
      })
    ))
  )
)

;; Place legal hold on documents
(define-public (place-legal-hold
  (document-ids (list 50 (string-ascii 64)))
  (hold-reason (string-ascii 500))
  (expected-end (optional uint))
)
  (let
    (
      (hold-id (var-get next-hold-id))
    )
    (asserts! (is-authorized-disposer) ERR-NOT-AUTHORIZED)
    (asserts! (> (len document-ids) u0) ERR-DOCUMENT-NOT-FOUND)

    ;; Place hold on each document
    (fold place-hold-on-document document-ids true)

    ;; Create hold record
    (map-set legal-holds
      { hold-id: hold-id }
      {
        document-ids: document-ids,
        hold-reason: hold-reason,
        initiated-by: tx-sender,
        initiated-at: block-height,
        expected-end: expected-end,
        is-active: true
      }
    )

    (var-set next-hold-id (+ hold-id u1))
    (ok hold-id)
  )
)

;; Helper function to place hold on individual document
(define-private (place-hold-on-document (document-id (string-ascii 64)) (prev-result bool))
  (match (map-get? document-retention { document-id: document-id })
    retention-data
      (begin
        (map-set document-retention
          { document-id: document-id }
          (merge retention-data {
            hold-status: true,
            hold-reason: (some "Legal hold applied")
          })
        )
        prev-result
      )
    prev-result
  )
)

;; Dispose document
(define-public (dispose-document
  (document-id (string-ascii 64))
  (disposal-method (string-ascii 50))
  (disposal-reason (string-ascii 200))
  (witness (optional principal))
  (certificate-hash (optional (buff 32)))
)
  (let
    (
      (retention-data (unwrap! (map-get? document-retention { document-id: document-id }) ERR-DOCUMENT-NOT-FOUND))
      (disposal-id (var-get next-disposal-id))
    )
    (asserts! (is-authorized-disposer) ERR-NOT-AUTHORIZED)
    (asserts! (var-get disposal-enabled) ERR-CANNOT-DISPOSE)
    (asserts! (not (get hold-status retention-data)) ERR-CANNOT-DISPOSE)
    (asserts! (>= block-height (get disposal-date retention-data)) ERR-CANNOT-DISPOSE)
    (asserts! (is-eq (get current-action retention-data) ACTION-DISPOSE) ERR-CANNOT-DISPOSE)

    ;; Record disposal
    (map-set disposal-records
      { disposal-id: disposal-id }
      {
        document-id: document-id,
        disposed-at: block-height,
        disposed-by: tx-sender,
        disposal-method: disposal-method,
        disposal-reason: disposal-reason,
        witness: witness,
        certificate-hash: certificate-hash
      }
    )

    (var-set next-disposal-id (+ disposal-id u1))
    (ok disposal-id)
  )
)

;; Release legal hold
(define-public (release-legal-hold (hold-id uint))
  (let
    (
      (hold-data (unwrap! (map-get? legal-holds { hold-id: hold-id }) ERR-SCHEDULE-NOT-FOUND))
    )
    (asserts! (is-authorized-disposer) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active hold-data) ERR-SCHEDULE-NOT-FOUND)

    ;; Release hold on each document
    (fold release-hold-on-document (get document-ids hold-data) true)

    ;; Deactivate hold
    (ok (map-set legal-holds
      { hold-id: hold-id }
      (merge hold-data { is-active: false })
    ))
  )
)

;; Helper function to release hold on individual document
(define-private (release-hold-on-document (document-id (string-ascii 64)) (prev-result bool))
  (match (map-get? document-retention { document-id: document-id })
    retention-data
      (begin
        (map-set document-retention
          { document-id: document-id }
          (merge retention-data {
            hold-status: false,
            hold-reason: none
          })
        )
        prev-result
      )
    prev-result
  )
)

;; Read-only Functions

;; Get retention schedule
(define-read-only (get-retention-schedule (schedule-id uint))
  (map-get? retention-schedules { schedule-id: schedule-id })
)

;; Get document retention info
(define-read-only (get-document-retention (document-id (string-ascii 64)))
  (map-get? document-retention { document-id: document-id })
)

;; Get disposal record
(define-read-only (get-disposal-record (disposal-id uint))
  (map-get? disposal-records { disposal-id: disposal-id })
)

;; Get legal hold
(define-read-only (get-legal-hold (hold-id uint))
  (map-get? legal-holds { hold-id: hold-id })
)

;; Check if document is eligible for disposal
(define-read-only (is-eligible-for-disposal (document-id (string-ascii 64)))
  (match (map-get? document-retention { document-id: document-id })
    retention-data
      (and
        (var-get disposal-enabled)
        (not (get hold-status retention-data))
        (>= block-height (get disposal-date retention-data))
        (is-eq (get current-action retention-data) ACTION-DISPOSE)
      )
    false
  )
)

;; Check if document is on legal hold
(define-read-only (is-on-legal-hold (document-id (string-ascii 64)))
  (match (map-get? document-retention { document-id: document-id })
    retention-data (get hold-status retention-data)
    false
  )
)

;; Get documents due for action
(define-read-only (get-documents-due-for-action (action uint))
  ;; In a full implementation, this would return a list of document IDs
  ;; For now, return the next schedule ID as a placeholder
  (var-get next-schedule-id)
)

;; Check if disposal is enabled
(define-read-only (is-disposal-enabled)
  (var-get disposal-enabled)
)
