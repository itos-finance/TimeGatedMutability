# TimeGatedMutability
Libraries and Facets for adding Time-Gated contract mutability.

## Security
Our prescriptive stance is that human-reviewed security can be good but is never 100% secure.
It is irresponsible for smart contracts to not include operational failsafes like circuit-breakers.

This repository contains useful utilities for adding said failsafes.

## Mutability
Once an exploit is found, there should be a way to patch them but there arises a problem of mutability. 
If the contract is completely mutable, it is prone to rugs, incorrect parameterization, and backwards-compat breaks.
If the contract is completely immutable, once a bug if found the contract is dead. It is a race against time for users
to salvage what they can, and this shouldn't be the user's responsibility.

Time-gating is the middle ground. We split into 4 categories.
1. Un-gated
2. Short-gated
3. Medium-gated
4. Long-gated

### Un-gated operations
Method halts, blacklists, and complete circuit breakers are un-gated. Contract admins can't rug or modify
the contract, but can cease operations. Admins stand to gain nothing here except for securing the protocol. Perhaps a really bad-actor 
wants to permanently halt a protocol. This is why all halts should have a deadline, and subsequent halts require a quorum.

Halts can also be undone through governance approval. Unhalts are typically short-gated operations. Halting privileges can also be revoked through governance.

### Short-gated operations.
Minute parameter changes can be gated for just a short period of time. The duration allows other participants to validate the parameters.
This time duration is on the duration of hours to days. Changes can be veto'd by anyone with veto power (typically OpSec teams and the DAO). 

### Medium-gated operations.
Minor code changes usually through Facet cuts (EIP-2535). These require a sizeable amount of time to review, and often require governance approval.
They should first be proposed and reviewed by white-hats. Can be vetoed. Gating duration usually on the order of days.

### Long-gated Operations.
Very significant code changes. Almost always facet cuts. They require multiple audits and governance approval. Can be vetoed.
Gating duration is on the order of weeks.


