# TimeGatedMutability
Libraries, Mixins, and Diamond Facets for adding Time-Gated contract mutability.
Remember that Facets can also be used as Mixins.

This repo covers two forms of mutability: storage parameter updates and diamond cuts.
1. Parameter updating. Provides Access control, Veto powers, and Time-gating for parameter updates.
2. Timed Diamond Cut: Drop-in replacement for diamond cuts which adds time-gating and confirmation steps to diamond cuts along with access-control and veto power.

Currently, optimized for readability instead of gas. Appropriate for L2 usage and potentially L1.
If you want further gas optimizations, consider using the roles from Solady.

This is best used in conjunction with other OpSec measures like circuit breakers.

## Getting Started

```sh
forge install --no-commit itos-finance/TimeGatedMutability@v0.1.0
```

Then I recommend adding this to your remappings.txt to shorten imports.
```text
@itos/TGM/=lib/TimeGatedMutability/src/
```

## Security
Our prescriptive stance is that human-reviewed security can be good but is never 100% secure.
It is irresponsible for smart contracts to not include operational failsafes like circuit-breakers.

This repository contains useful utilities for adding said failsafes.

## Mutability
Once an exploit is found, there should be a way to patch them but there arises a problem of mutability.
If the contract is completely mutable, it is prone to rugs, incorrect parameterization, and backwards-compat breaks.
If the contract is completely immutable, once a bug is found then the contract is effectively dead. It is a race against time for users
to salvage what they can and users bear the loss. However, the responsibility shouldn't rest on user, but on the protocol and its governing body (DAO/team/investors).

Time-gating is the middle ground. We split into 4 categories.
1. Un-gated
2. Short-gated
3. Medium-gated
4. Long-gated

### Un-gated operations
Method halts, blacklists, and complete circuit breakers are un-gated. Contract admins can't rug or modify
the contract, but can cease operations. Admins stand to gain nothing here except for securing the protocol. Perhaps a really bad-actor
wants to permanently halt a protocol. This is why all halts should have a deadline, and subsequent halt continuations require a quorum.

Halts can also be undone through governance approval. Unhalts are typically short-gated operations. Halting privileges can also be revoked through governance.

### Short-gated operations.
Minor parameter changes can be gated for just a short period of time. The duration allows other participants to validate the parameters.
This time duration is on the duration of hours to days. Changes can be veto'd by anyone with veto power (typically OpSec teams and the DAO).

### Medium-gated operations.
Minor code changes usually through Facet cuts (EIP-2535). These require a sizeable amount of time to review, and often require governance approval.
They should first be proposed and tested/reviewed by white-hats. Can be vetoed. Gating duration usually on the order of days.

### Long-gated Operations.
Very significant code changes. Almost always facet cuts. They require multiple audits and governance approval. Can be vetoed.
Gating duration is on the order of weeks.

# Example Usage

### For parameter updating
```
contract Updateable {
    ...

    uint256 constant public UPDATE_KEY = 1337;
    uint256 constant public TIME_DATE_DELAY = 1 days;
    uint256 constant public UPDATE_RIGHTS = 0xDEADBEEF;

    uint256 public param;

    // Step 1
    function startUpdate(uint256 newVal) external {
        // Check access
        AdminLib.validateRights(UPDATE_RIGHTS);

        // initiate update
        Timed.precommit(UPDATE_KEY, abi.encode(newVal));
    }

    // Step done
    function useNewVal() external {
        AdminLib.validateRights(CAN_CONFIRM);
        bytes memory data = Timed.fetchPrecommit(UPDATE_KEY, TIME_DATE_DELAY);
        param = abi.decode(data, (uint256));
        emit ParamUpdated(param);
    }

    // In practice, contracts have multiple parameters. They can all share one "confirm" and one "veto" method
    // by taking in the useId as a parameter.
}
```

### For Diamond Cuts:
If you're familiar with EIP-2535 Diamonds, then simply Diamond Cut to replace your DiamondCut facet with an implementation of the TimedDiamondCutFacet.
The implementation needs to fill in the delay and validation methods.

Then any cuts you do are time-gated and need confirmation. See scripts for example confirmation and veto usage.
