# Business Revenue Model

This repo now has one concrete revenue primitive:
`SuperNeoRevenueLogic.billableAcceptedVerificationEvent(...)`.

## Sellable Units

1. `accepted-numiseal-zk-verification`
   - Unit: one accepted product-control verification.
   - Required evidence: accepted audit event, `proofKind = "numiseal-zk"`,
     artifact digest, proof-envelope digest, provenance digest, statement digest,
     issued-QRO digest, release build digest, customer ID, and rate card.
   - Non-billable: rejected verification, local/dev raw-QRO verification, fold,
     terminal, compressed-terminal, or missing-QRO events.

2. `issued-qro-challenge`
   - Unit: one signed QRO challenge issued by a hosted QRO service.
   - Required before billing in production: hosted issuer logs, single-use
     consumption state, customer attribution, and refund/retry policy.

3. `verifier-seat-monthly`
   - Unit: one customer verifier/operator seat per month.
   - Required before billing in production: account identity, entitlement checks,
     seat activation/deactivation timestamps, and invoice export.

4. `support-contract-monthly`
   - Unit: one support contract month.
   - Required before billing in production: signed order form or subscription
     record, SLA tier, and support scope.

## Margin Logic

For accepted product verification:

```text
totalRevenueMicrosUSD = unitPriceMicrosUSD * quantity
estimatedTotalCostMicrosUSD =
  verificationCompute + artifactStorage + artifactEgress + qroService
grossMarginBasisPoints =
  (totalRevenueMicrosUSD - estimatedTotalCostMicrosUSD) * 10000 / totalRevenueMicrosUSD
```

The event records both actual margin and target margin. Pricing is acceptable
only when the event clears the target margin and the benchmark/cost inputs are
fresh for the deployment class.

## Required Hosted Revenue Controls

- Strongly consistent replay/QRO consumption ledger across verifier nodes.
- Customer/account identity bound to every issued QRO and verification request.
- Signed billable-event export into the billing system.
- Refund policy for verifier errors, expired context material, and revoked
  artifacts.
- Rate limits and abuse monitoring before public API access.
- Audit retention policy separate from local JSONL verifier logs.

Until those controls exist, the repository supports library/CLI product-control
verification and deterministic billable-event construction, not a complete SaaS
billing stack.
