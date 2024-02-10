pragma solidity =0.8.22;


library SigningTools
	{
		// info : using contract to keep out of storage array and save gas  
	// The public address of the signer for verfication of BootstrapBallot voting and default AccessManager

	// does this need to be public ? , attacker can use this to verify signature and then use it to call the function
	// q : why you keeping it on chain ? 
	address constant public EXPECTED_SIGNER = 0x1234519DCA2ef23207E1CA7fd70b96f281893bAa;
    

	// @audit-info : maybe signature replay attack ? lol ? maybe just :)

	// Verify that the messageHash was signed by the authoratative signer.
    function _verifySignature(bytes32 messageHash, bytes memory signature ) internal pure returns (bool)
    	{
    	require( signature.length == 65, "Invalid signature length" );

		bytes32 r;
		bytes32 s;
		uint8 v;

		assembly
			{
			r := mload (add (signature, 0x20))
			s := mload (add (signature, 0x40))
			v := mload (add (signature, 0x41))
			}

		address recoveredAddress = ecrecover(messageHash, v, r, s);

        return (recoveredAddress == EXPECTED_SIGNER);
    	}
	}
