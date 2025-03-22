/// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract Escrow {
    address public parentContract;
    address public oracle;
    address payable public seller;
    address payable public buyer;
    uint256 public value;
    uint256 public propertyId;
    uint256 public timeout;
    bool public inUse;

    event TransactionComplete(
        address _buyer,
        address _seller,
        uint256 _propertyId
    );
    event CheckTimeout(uint256 time);
    event TimeoutStatus(bool status);

    constructor(
        address _oracle,
        address payable _seller,
        address payable _buyer,
        uint256 _value,
        uint256 _propertyId,
        uint256 _timeout
    ) payable {
        parentContract = msg.sender;
        oracle = _oracle;
        seller = _seller;
        buyer = _buyer;
        value = _value;
        propertyId = _propertyId;
        timeout = _timeout;
        inUse = true;
    }

    function checkStatus() public {
        require(inUse, "Escrow not in use"); // Contract is still in use
        require(msg.sender == seller, "Only seller can call this function");
        emit CheckTimeout(timeout); // gives sellers an option to kill escrow after timeout
    }

    function deposit() public payable {
        require(inUse, "Escrow not in use"); // Contract is still in use
        require(msg.sender == buyer, "Only buyer can call this function");
        require(msg.value == value, "Incorrect value deposited");

        emit CheckTimeout(timeout); // Notify oracle to check
    }

    function timeoutStatus(bool isTimeout) public {
        require(inUse, "Escrow not in use"); // Contract is still in use
        require(msg.sender == oracle, "Only oracle can call");

        emit TimeoutStatus(isTimeout);

        if (isTimeout) {
            // reset escrow for the relevant property
            (bool success, ) = parentContract.call(
                abi.encodeWithSignature(
                    "resetPropertyEscrow(uint256)",
                    propertyId
                )
            );
            require(success, "Reset property escrow failed");
            inUse = false; // disable contract
            // Transfer payment back to buyer if timeout
            payable(buyer).transfer(address(this).balance);
        } else {
            if (address(this).balance == value) {
                // transfer title to new owner
                (bool transferPropertySuccess, ) = parentContract.call(
                    abi.encodeWithSignature(
                        "transferProperty(uint256,address,address)",
                        propertyId,
                        buyer,
                        seller
                    )
                );
                require(transferPropertySuccess, "Transfer property failed");

                inUse = false; // disable contract
                // Transfer payment to seller if not timeout
                payable(seller).transfer(address(this).balance);

                emit TransactionComplete(buyer, seller, propertyId); // event for orcale to trigger property transfer
            }
        }
    }
}
