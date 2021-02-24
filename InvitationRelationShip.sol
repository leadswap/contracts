pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import './interfaces/IDelegate.sol';

interface IDAO {
    function getercBalanceof(address owner) external view returns (uint);
}


// contract DAO is IDAO {
//     function getercBalanceof(address owner) external view returns (uint){
//         return 1;
//     }
// }

contract InvitationRelationShip is IDelegate {
    
    event AddRelation(address, address);
    event DelRelation(address, address);
    event SetDaoConAddr(address);
    
    address constant ZERO_ADDRESS = address(0);
    
    modifier onlyOwner() {
        require(msg.sender == conOwnerAddr, "for contract owner only");
        _;
    }
    
    modifier needDaoConAddrSet() {
        require(daoAddress != ZERO_ADDRESS, "dao contract address not set");
        _;
    }
    
    modifier needAddrExist(address addr) {
        require(addrToDelegateAddr[addr] != ZERO_ADDRESS, "address is not existed");
        _;
    }
    
    modifier needAddrNotExist(address addr) {
        require(addrToDelegateAddr[addr] == ZERO_ADDRESS, "address has been existed already");
        _;
    }
    
    modifier needHasInvitationRelation(address addr, address inviter) {
        require(addrToDelegateAddr[addr] == inviter, "no invitation relation");
        _;
    }
    
    constructor() public {
        conOwnerAddr = msg.sender;
        
        // TODO init Invitation root address
        deleRootAddr = address(0x30AA782A4631307F9A1c05EbD20467Ac6F0D7B0A);
        
        // TODO reward ranks
        rewardRanks = 2;
        
        // TODO reward ranks detail (percent)
        rewardRanksDetail = [10, 5];
        

        // TODO max delegate ranks to trace
        maxDelegateRanks = 2;
    }
    
    function set_dao_contract_address(address daoConAddr) external
    onlyOwner()
    {
        daoAddress = daoConAddr;
        emit SetDaoConAddr(daoConAddr);
    }
    
    function add_invitation_relation(address inviterCode) 
    needDaoConAddrSet()
    needAddrNotExist(msg.sender)
    external {
        if ((inviterCode == deleRootAddr) || (inviterCode == ZERO_ADDRESS)) {
            addrToDelegateAddr[msg.sender] = deleRootAddr;
            addrToMemberAddrs[deleRootAddr].push(msg.sender);
            emit AddRelation(msg.sender, inviterCode);
            return;
        } else {
            require(addrToDelegateAddr[inviterCode] != ZERO_ADDRESS, "address is not existed");
        }
        
        addrToDelegateAddr[msg.sender] = inviterCode;
        addrToMemberAddrs[inviterCode].push(msg.sender);
        
        emit AddRelation(msg.sender, inviterCode);
    }
    
    function getDelegateRewardRanks(address addr) external view returns (DelegatePre[] memory)
    {
        uint32 index = 0;
        DelegatePre[] memory delegatePreRet = new DelegatePre[] (rewardRanks);
        address memberAddr = addr;
    	for(;;) {
    	    address delegateAddr = addrToDelegateAddr[memberAddr];
    	    if (delegateAddr == ZERO_ADDRESS) {
    	        break;
    	    }
    	    
    	    delegatePreRet[index].delegateAddr = delegateAddr;
    	    delegatePreRet[index].delegateReward = rewardRanksDetail[index];
    	    
    	    if (index >= rewardRanks - 1) {
    	        break;
    	    }
    	    
    	    memberAddr = delegateAddr;
    	    index++;
    	}
    	
    	return delegatePreRet;
    }
    
    function getCaller() external view returns (address) {
        return msg.sender;
    }
    
    function getDaoContractAddr() external view returns (address) {
        return daoAddress;
    }
    
    function getConOwnerAddr() external view returns (address) {
        return conOwnerAddr;
    }
    
    function getDelegateRoot() external view returns (address) {
        return deleRootAddr;
    }
    
    function getDelegate(address addr) external view returns (address) 
    {
        address delegateAddr = addrToDelegateAddr[addr];
        return delegateAddr;
    }
    
    function getMembersCount(address deleAddr) external view returns (uint32)
    {
        address[] memory memberAddrs = addrToMemberAddrs[deleAddr];
        return uint32(memberAddrs.length);
    }
    
    function getMembers(address deleAddr) external view returns (address[] memory)
    {
        address[] memory memberAddrs = addrToMemberAddrs[deleAddr];
        return memberAddrs;
    }
    
    // struct DelegatePre{
    //     address delegateAddr;
    //     uint32  delegateReward;
    // }
    
    // contract owner address
    address internal conOwnerAddr;
    
    // DAO contract address
    address internal daoAddress;
    
    // delegate root address
    address internal deleRootAddr;
    
    // token reward ranks
    uint32 internal rewardRanks;
    
    // token reward details
    uint32[] internal rewardRanksDetail;
    
    // max delegate ranks to trace
    uint32 internal maxDelegateRanks;
    
    // k-v from member address to delegate address
    mapping(address => address) internal addrToDelegateAddr;
    
    // k-v from delegate address to member addresses
    mapping(address => address[]) internal addrToMemberAddrs;
}
