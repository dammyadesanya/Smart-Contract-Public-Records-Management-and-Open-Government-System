;; Public Access Request Management Contract
;; Streamlines access to government records for citizens

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-REQUEST-NOT-FOUND (err u201))
(define-constant ERR-INVALID-STATUS (err u202))
(define-constant ERR-REQUEST-EXISTS (err u203))
(define-constant ERR-DEADLINE-PASSED (err u204))
(define-constant ERR-INVALID-REQUEST (err u205))

;; Request Status Constants
(define-constant STATUS-PENDING u1)
(define-constant STATUS-UNDER-REVIEW u2)
(define-constant STATUS-APPROVED u3)
(define-constant STATUS-DENIED u4)
(define-constant STATUS-FULFILLED u5)
(define-constant STATUS-APPEALED u6)

;; Default processing time (in blocks)
(define-constant DEFAULT-PROCESSING-TIME u1440) ;; ~10 days

;; Data Variables
(define-data-var next-request-id uint u1)
(define-data-var processing-fee uint u0)

;; Data Maps
(define-map access-requests
  { request-id: uint }
  {
    requester: principal,
    document-ids: (list 10 (string-ascii 64)),
    request-type: (string-ascii 20),
    description: (string-ascii 500),
    status: uint,
    submitted-at: uint,
    deadline: uint,
    processing-notes: (string-ascii 1000),
    assigned-to: (optional principal),
    fee-paid: uint
  }
)

(define-map request-responses
  { request-id: uint }
  {
    response-text: (string-ascii 2000),
    documents-provided: (list 10 (string-ascii 64)),
    redacted-documents: (list 10 (string-ascii 64)),
    denial-reason: (optional (string-ascii 500)),
    responded-at: uint,
    responded-by: principal
  }
)

(define-map authorized-processors
  { processor: principal }
  { is-authorized: bool, department: (string-ascii 100) }
)

(define-map request-appeals
  { request-id: uint }
  {
    appeal-reason: (string-ascii 1000),
    appealed-at: uint,
    appeal-status: uint,
    appeal-response: (optional (string-ascii 1000))
  }
)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-processor)
  (default-to false
    (get is-authorized
      (map-get? authorized-processors { processor: tx-sender })
    )
  )
)

(define-private (is-valid-status (status uint))
  (and (>= status u1) (<= status u6))
)

;; Public Functions

;; Authorize a processor
(define-public (authorize-processor (processor principal) (department (string-ascii 100)))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-processors
      { processor: processor }
      { is-authorized: true, department: department }
    ))
  )
)

;; Set processing fee
(define-public (set-processing-fee (fee uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set processing-fee fee))
  )
)

;; Submit a new access request
(define-public (submit-request
  (document-ids (list 10 (string-ascii 64)))
  (request-type (string-ascii 20))
  (description (string-ascii 500))
)
  (let
    (
      (request-id (var-get next-request-id))
      (current-fee (var-get processing-fee))
    )
    (asserts! (> (len document-ids) u0) ERR-INVALID-REQUEST)
    (asserts! (> (len description) u0) ERR-INVALID-REQUEST)

    ;; TODO: In a real implementation, handle fee payment here

    (map-set access-requests
      { request-id: request-id }
      {
        requester: tx-sender,
        document-ids: document-ids,
        request-type: request-type,
        description: description,
        status: STATUS-PENDING,
        submitted-at: block-height,
        deadline: (+ block-height DEFAULT-PROCESSING-TIME),
        processing-notes: "",
        assigned-to: none,
        fee-paid: current-fee
      }
    )

    (var-set next-request-id (+ request-id u1))
    (ok request-id)
  )
)

;; Assign request to processor
(define-public (assign-request (request-id uint) (processor principal))
  (let
    (
      (request-data (unwrap! (map-get? access-requests { request-id: request-id }) ERR-REQUEST-NOT-FOUND))
    )
    (asserts! (is-authorized-processor) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request-data) STATUS-PENDING) ERR-INVALID-STATUS)

    (ok (map-set access-requests
      { request-id: request-id }
      (merge request-data {
        status: STATUS-UNDER-REVIEW,
        assigned-to: (some processor)
      })
    ))
  )
)

;; Update request status
(define-public (update-request-status
  (request-id uint)
  (new-status uint)
  (notes (string-ascii 1000))
)
  (let
    (
      (request-data (unwrap! (map-get? access-requests { request-id: request-id }) ERR-REQUEST-NOT-FOUND))
    )
    (asserts! (is-authorized-processor) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-status new-status) ERR-INVALID-STATUS)

    (ok (map-set access-requests
      { request-id: request-id }
      (merge request-data {
        status: new-status,
        processing-notes: notes
      })
    ))
  )
)

;; Respond to request
(define-public (respond-to-request
  (request-id uint)
  (response-text (string-ascii 2000))
  (documents-provided (list 10 (string-ascii 64)))
  (redacted-documents (list 10 (string-ascii 64)))
  (denial-reason (optional (string-ascii 500)))
)
  (let
    (
      (request-data (unwrap! (map-get? access-requests { request-id: request-id }) ERR-REQUEST-NOT-FOUND))
      (new-status (if (is-some denial-reason) STATUS-DENIED STATUS-FULFILLED))
    )
    (asserts! (is-authorized-processor) ERR-NOT-AUTHORIZED)
    (asserts! (< block-height (get deadline request-data)) ERR-DEADLINE-PASSED)

    ;; Update request status
    (map-set access-requests
      { request-id: request-id }
      (merge request-data { status: new-status })
    )

    ;; Store response
    (ok (map-set request-responses
      { request-id: request-id }
      {
        response-text: response-text,
        documents-provided: documents-provided,
        redacted-documents: redacted-documents,
        denial-reason: denial-reason,
        responded-at: block-height,
        responded-by: tx-sender
      }
    ))
  )
)

;; Submit appeal
(define-public (submit-appeal (request-id uint) (appeal-reason (string-ascii 1000)))
  (let
    (
      (request-data (unwrap! (map-get? access-requests { request-id: request-id }) ERR-REQUEST-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get requester request-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request-data) STATUS-DENIED) ERR-INVALID-STATUS)

    ;; Update request status to appealed
    (map-set access-requests
      { request-id: request-id }
      (merge request-data { status: STATUS-APPEALED })
    )

    ;; Store appeal
    (ok (map-set request-appeals
      { request-id: request-id }
      {
        appeal-reason: appeal-reason,
        appealed-at: block-height,
        appeal-status: STATUS-PENDING,
        appeal-response: none
      }
    ))
  )
)

;; Read-only Functions

;; Get request details
(define-read-only (get-request (request-id uint))
  (map-get? access-requests { request-id: request-id })
)

;; Get request response
(define-read-only (get-request-response (request-id uint))
  (map-get? request-responses { request-id: request-id })
)

;; Get appeal details
(define-read-only (get-appeal (request-id uint))
  (map-get? request-appeals { request-id: request-id })
)

;; Check if request is overdue
(define-read-only (is-request-overdue (request-id uint))
  (match (map-get? access-requests { request-id: request-id })
    request-data (> block-height (get deadline request-data))
    false
  )
)

;; Get requests by requester
(define-read-only (get-requester-requests (requester principal))
  ;; In a full implementation, this would use a secondary index
  ;; For now, return the next request ID as a placeholder
  (var-get next-request-id)
)

;; Get current processing fee
(define-read-only (get-processing-fee)
  (var-get processing-fee)
)

;; Check processor authorization
(define-read-only (is-processor-authorized (processor principal))
  (default-to false
    (get is-authorized
      (map-get? authorized-processors { processor: processor })
    )
  )
)
