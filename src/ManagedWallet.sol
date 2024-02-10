// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "./interfaces/IManagedWallet.sol";

// A smart contract which provides two wallet addresses (a main and confirmation wallet) which can be changed using the following mechanism:
// 1. Main wallet can propose a new main wallet and confirmation wallet.
// 2. Confirmation wallet confirms or rejects.
// 3. There is a timelock of 30 days before the proposed mainWallet can confirm the change.

contract ManagedWallet is IManagedWallet {
    event WalletProposal(
        address proposedMainWallet,
        address proposedConfirmationWallet
    );
    event WalletChange(address mainWallet, address confirmationWallet);

    uint256 public constant TIMELOCK_DURATION = 30 days;

    // The active main and confirmation wallets
    address public mainWallet;
    address public confirmationWallet;
    
	// q : why the variable are public ? 
	// a : because the contract is not upgradable, so the variables are public to allow the users to check the state of the contract.
	// q : why the variables are not immutable ?
	// a : because the contract is not upgradable, so the variables are not immutable to allow the users to change the state of the contract.


    // Proposed wallets
    address public proposedMainWallet;
    address public proposedConfirmationWallet;

    // Active timelock
    uint256 public activeTimelock;

    constructor(address _mainWallet, address _confirmationWallet) {
        mainWallet = _mainWallet;
        confirmationWallet = _confirmationWallet;

        // Write a value so subsequent writes take less gas
        activeTimelock = type(uint256).max;
    }

    // Make a request to change the main and confirmation wallets.

	// what is the role of propose wallet ?


    function proposeWallets(
        address _proposedMainWallet,
        address _proposedConfirmationWallet
    ) external {
        require(
            msg.sender == mainWallet,
            "Only the current mainWallet can propose changes"
        );
        require(
            _proposedMainWallet != address(0),
            "_proposedMainWallet cannot be the zero address"
        );
        require(
            _proposedConfirmationWallet != address(0),
            "_proposedConfirmationWallet cannot be the zero address"
        );

		// q : to many checks ? , causing access gas ?
		// a : yes, but the contract is not upgradable, so the checks are necessary to avoid bugs.


        // Make sure we're not overwriting a previous proposal (as only the confirmationWallet can reject proposals)
        require(
            proposedMainWallet == address(0),
            "Cannot overwrite non-zero proposed mainWallet."
        );

        proposedMainWallet = _proposedMainWallet;
        proposedConfirmationWallet = _proposedConfirmationWallet;

        emit WalletProposal(proposedMainWallet, proposedConfirmationWallet);
    }

    // The confirmation wallet confirms or rejects wallet proposals by sending a specific amount of ETH to this contract
    receive() external payable {
        require(msg.sender == confirmationWallet, "Invalid sender");

        // Confirm if .05 or more ether is sent and otherwise reject.
        // Done this way in case custodial wallets are used as the confirmationWallet - which sometimes won't allow for smart contract calls.
        if (msg.value >= .05 ether)
            activeTimelock = block.timestamp + TIMELOCK_DURATION; // establish the timelock
        else activeTimelock = type(uint256).max; // effectively never
    }

    // Confirm the wallet proposals - assuming that the active timelock has already expired.
    function changeWallets() external {
        // proposedMainWallet calls the function - to make sure it is a valid address.
        require(msg.sender == proposedMainWallet, "Invalid sender");
        require(
            // @audit medium : block.timestamp can be manipulated , Miners have some ability to manipulate this value, which could potentially allow them to execute the function before the intended time.
            block.timestamp >= activeTimelock,
            "Timelock not yet completed"

			// q : block.timestamp is not a good way to check the time, because it can be manipulated by miners.
        );

        // Set the wallets
        mainWallet = proposedMainWallet;
        confirmationWallet = proposedConfirmationWallet;

        emit WalletChange(mainWallet, confirmationWallet);

        // Reset
        activeTimelock = type(uint256).max;
        proposedMainWallet = address(0);
        proposedConfirmationWallet = address(0);
    }
}
