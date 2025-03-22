// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
import "../contracts/PropertyManagement.sol";
import "../contracts/Escrow.sol";

// File name has to end with '_test.sol', this file can contain more than one testSuite contracts
contract PropertyManagementTest is PropertyManagement(){
    Escrow private escrowInstance;
    address payable acc0;
    address payable acc1;
    address payable acc2;
    address payable acc3;
    address acc4;
    Property testProperty = Property(0, "1highSt", 1000000000000000000 , "HASH1", "55", acc1, Approval.Pending);

    function beforeAll() public {
        // Initiate account variables
        acc0 = payable(TestsAccounts.getAccount(0)); // going to use as authority addresss
        acc1 = payable(TestsAccounts.getAccount(1)); // going to use as seller 
        acc2 = payable(TestsAccounts.getAccount(2)); // going to user as buyer
        acc3 = payable(TestsAccounts.getAccount(3));
        acc4 = TestsAccounts.getAccount(4); // going to use as oracle address
        testProperty.owner = acc1;
        
    }
    
    /// Makes sure acc0 is authority
    function authorityTest() public {
        Assert.equal(authority, acc0, "Authority should be ac0");
    }
    
    /// Test to ensure only authority can set oracle address
    /// #sender: account-1
    function setOracleFailure() public {
        try this.oracleAddress(acc4) {

        } catch Error (string memory reason) {
            Assert.equal(reason, 'Insufficient rights to perform this operation', 'Only auth can set Oracle');
        }
    }

    /// Set the oracle address
    /// #sender: account-0 
    function setOracle() public {
        oracleAddress(acc4);
        Assert.equal(oracle, acc4, 'Oracle should be acc4'); 
    }  

    

    /// Test registering a house
    /// #sender: account-1
    function RegisterProperty() public {
        registerProperty("1highSt", 1000000000000000000, "HASH1", "55");
        Assert.equal(getPropertyOwnerAddress(0), acc1, "House owner is diff");     
        Assert.equal(getPropertyLocation(0), testProperty.location, 'Address does not match');
        Assert.equal(getPropertyId("1highSt"), testProperty.id, 'id does not match');
        Assert.equal(getPropertyValue(0), testProperty.value, 'value does not match');
        Assert.equal(getPropertyHash(0), testProperty.documentHash, 'document hash does not match');
    }

    /// Test putting property for sale should fail as property not approved
    /// #sender: account-1
    function failedSale() public {
        (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("onSale(uint256)", 0));
        if (!success) {
            assembly {
                result := add(result, 0x04)
            }
            string memory reason = abi.decode(result, (string));
            Assert.equal(reason,"Property is not approved", "Method failed for different reason");
        }
        Assert.equal(checkSale(0), false, "House should not be on sale");

    }

    /// Test to see only oracle can approve the house- should fail
    /// #sender: account-3
    function failedAapproveHouse() public {
        try this.approveProperty(0, true) {

        } catch Error (string memory reason) {
            Assert.equal(reason, 'Only oracle can call', 'failed unexpectedly');
        }
    }

    /// Oracle to approve the house
    /// #sender: account-4
    function approveHouse() public {
        approveProperty(0, true);
        Assert.equal(getPropertyStatus(0), "Approved", "House should be approved");
    }

    /// Testing Owner can now put on sale
    /// #sender: account-1
    function forSale() public {
        (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("onSale(uint256)", 0));
        Assert.equal(success, true, "Method failed for different reason");
        string memory reason = abi.decode(result, (string));
        Assert.equal(reason, "1highSt is now on sale", "House should  be on sale");
        Assert.equal(checkSale(0), true, "House should  be on sale");
    }

    /// Owner tries to buy own property should fail
    /// #sender: account-1
    function buyHouseFail() public {
        (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("buyProperty(uint256)", 0));
        Assert.equal(success, false, "Method failed for different reason");
        assembly {
            result := add(result, 0x04)
        }
        string memory reason = abi.decode(result, (string));
        Assert.equal(reason, "You already own this property", "Owner should not be able to buy");
    }

    /// trying to buy property should generate a escrow contract address
    /// #sender: account-2
    function buyHouse() public {
        (bool success, ) = address(this).delegatecall(abi.encodeWithSignature("buyProperty(uint256)", 0));
        Assert.equal(success, true, "Method failed for different reason");
        Assert.notEqual(propertyEscrow[0], address(0), "Escrow address should not be empty");
        address escrowAddress = propertyEscrow[0];
        escrowInstance = Escrow(escrowAddress);
    }

    /// Tests only oracle can call timeoutstatus in escrow contract
    /// #sender: account-4
    function timeoutStatus() public {
        Assert.notEqual(propertyEscrow[0], address(0), "Escrow contract should not be empty");
        escrowInstance =  Escrow(propertyEscrow[0]);
        (bool success, ) = address(escrowInstance).delegatecall(abi.encodeWithSignature("timeoutStatus(bool)",false));
        Assert.equal(success, true, "Method failed for different reason");
    }
    
    /// Testing only escrowcontract address or authority can call transfer function - should fail 
    /// #sender: account-1
    function failTitleTransfer() public {
        try this.transferProperty(0, acc2, acc1) {

        } catch Error (string memory reason) {
            Assert.equal(reason, 'Transfer not initiated by valid escrow or authority', 'failed unexpectedly');
        }
    }

    /// Testing successfull title transfer call using authority
    /// #sender: account-0
    function titleTransfer() public {
        Assert.equal(getPropertyOwnerAddress(0), acc1, "incorrect current owner");
        transferProperty(0, acc2, acc1);
        Assert.equal(getPropertyOwnerAddress(0), acc2, "incorrect new owner");
    }


    /// Testing new owner should not be able to put it on sale until approved again by oracle
    /// #sender: account-2
    function saleHouse() public {
        (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("onSale(uint256)", 0));
        Assert.equal(success, false, "Method failed for different reason");
        assembly {
            result := add(result, 0x04)
        }
        string memory reason = abi.decode(result, (string));
        Assert.equal(reason,"Property is not approved", "Property should not be approved");
    }

    /// Oracle to approve the house again
    /// #sender: account-4
    function approveHouseAgain() public {
        approveProperty(0, true);
        Assert.equal(getPropertyStatus(0), "Approved", "House should be approved");
    }

    /// Testing only owner can change home value - should fail
    /// #sender: account-1
    function failChangeHomeValue() public {
        try this.changePrice(0, 15000){

        } catch Error (string memory reason) {
            Assert.equal(reason, "You are not the owner of the property", "only owner should be able to change price");
        }
    }

    /// Testing only owner can change home value - should pass
    /// #sender: account-2
    function changeHomeValue() public {
        changePrice(0, 15000);
        Assert.equal(getPropertyValue(0), 15000, "Value was not updated");
    }

    /// Testing only owner can change documenthash - should fail
    /// #sender: account-1
    function changeHashFail() public {
       try this.changeHash(0, "55", "newHASH") {

        } catch Error (string memory reason) {
            Assert.equal(reason, "You are not the owner of the property", "only owner should be able to change document hash");
        }
    }

    /// Testing only owner can change documenthash - should pass
    /// #sender: account-2
    function changeHashPass() public {
        changeHash(0, "55", "newHASH");
        Assert.equal(getPropertyHash(0), "newHASH", "Hash of documents was not updated");
    }

    /// Testing once a document hash has been changed property goes back to pending status
    /// #sender: account-2
    function approvalStatus() public {
        Assert.equal(getPropertyStatus(0), "Pending", "Status was not updated");
    }

}
